require "rails_helper"

RSpec.describe Digests::Builder do
  let(:user) { create(:user) }
  let(:today) { Date.new(2026, 9, 29) }
  let(:yesterday) { Date.new(2026, 9, 28) }
  let(:overview) do
    {
      traded_on: "2026-09-29", nepse_index: 2600.5, index_change_pct: -0.91, regime_status: "weak",
      advancing_stocks: 48, declining_stocks: 225, unchanged_stocks: 8, market_breadth_pct: 17.08,
      sectors: [
        { sector: "Hydropower", sector_performance_pct: -0.5 }, { sector: "Commercial Banks", sector_performance_pct: 0.4 },
        { sector: "Corporate Debentures", sector_performance_pct: -3.0 }, { sector: "Finance", sector_performance_pct: -1.2 },
        { sector: "Tradings", sector_performance_pct: 1.1 }, { sector: "Investment", sector_performance_pct: -2.0 }
      ]
    }
  end

  def snapshot(stock, day, in_buy_zone:, zone_state: in_buy_zone ? "in_zone" : "too_early", readiness: 70, guards: [], rules: 6)
    StockSetupSnapshot.create!(stock: stock, traded_on: day, close_price: 100, zone_state: zone_state, in_buy_zone: in_buy_zone,
                               readiness_score: readiness, trend_rules_passed: rules, guards: guards, setup_type: "vcp",
                               entry_zone_low: 98, entry_zone_high: 103)
  end

  before { allow(MarketIndex::Overview).to receive(:new).and_return(instance_double(MarketIndex::Overview, call: overview)) }

  it "summarises the market, leaving out debentures, with the best and worst sectors" do
    snapshot(create(:stock), today, in_buy_zone: false)

    market = described_class.call(user).content["market"]

    expect(market).to include("nepse_index" => 2600.5, "index_change_pct" => -0.91, "regime" => "weak", "advancing" => 48, "breadth_pct" => 17.08)
    expect(market["best_sectors"].map { _1["sector"] }).to eq([ "Tradings", "Commercial Banks", "Hydropower" ])
    expect(market["worst_sectors"].map { _1["sector"] }).to eq([ "Investment", "Finance", "Hydropower" ])
  end

  it "lists stocks that joined or left the board since the previous session, and held-back charts" do
    stay = create(:stock, symbol: "STAY")
    new_one = create(:stock, symbol: "NEWONE", name: "New One Ltd")
    gone = create(:stock, symbol: "GONE")
    thin = create(:stock, symbol: "THIN")
    snapshot(stay, yesterday, in_buy_zone: true)
    snapshot(stay, today, in_buy_zone: true)
    snapshot(new_one, yesterday, in_buy_zone: false)
    snapshot(new_one, today, in_buy_zone: true, readiness: 75)
    snapshot(gone, yesterday, in_buy_zone: true)
    snapshot(gone, today, in_buy_zone: false, zone_state: "extended", readiness: 58)
    snapshot(thin, today, in_buy_zone: false, zone_state: "in_zone", guards: [ "thin_volume" ])

    entry = described_class.call(user).content["entry_zone"]

    expect(entry["count"]).to eq(2)
    expect(entry["joined"].sole).to include("symbol" => "NEWONE", "name" => "New One Ltd", "readiness" => 75, "entry_zone_low" => 98.0)
    expect(entry["left"].sole).to include("symbol" => "GONE", "zone_state" => "extended", "readiness" => 58)
    expect(entry["held_back"]).to eq([ { "symbol" => "THIN", "guards" => [ "thin_volume" ] } ])
  end

  it "reports today's watchlist verdicts, the session's alerts and book closes within 10 days" do
    stock = create(:stock, symbol: "NABIL")
    other = create(:stock, symbol: "KBL")
    snapshot(stock, today, in_buy_zone: false)
    item = create(:watchlist_item, user: user, stock: stock, last_close_on: today, last_close_state: "held_zone", last_close_price: 505)
    create(:watchlist_item, user: user, stock: other, last_close_on: yesterday, last_close_state: "confirmed")
    Time.use_zone("Asia/Kathmandu") do
      user.watchlist_alerts.create!(watchlist_item: item, kind: "entered_zone", message: "NABIL entered its zone", created_at: Time.zone.local(2026, 9, 29, 13))
      user.watchlist_alerts.create!(watchlist_item: item, kind: "extended", message: "Old alert", created_at: Time.zone.local(2026, 9, 28, 13))
    end
    stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, cash_percent: 5, book_close_on: today + 4, source: "chukul")
    other.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: today + 30, source: "chukul")

    watch = described_class.call(user).content["watchlist"]

    expect(watch["tracked"]).to eq(2)
    expect(watch["verdicts"]).to eq([ { "symbol" => "NABIL", "setup_type" => "vcp", "state" => "held_zone", "close" => 505.0 } ])
    expect(watch["alerts"]).to eq([ { "symbol" => "NABIL", "kind" => "entered_zone", "message" => "NABIL entered its zone" } ])
    expect(watch["book_closes"]).to eq([ { "symbol" => "NABIL", "book_close_on" => "2026-10-03", "days_until" => 4, "bonus_percent" => 10.0, "cash_percent" => 5.0 } ])
  end

  it "includes only the sections the user chose, and replaces the content on a rebuild but keeps it read" do
    snapshot(create(:stock), today, in_buy_zone: false)
    user.update!(digest_sections: [ "market" ])

    digest = described_class.call(user)
    digest.update!(read_at: Time.current)
    rebuilt = described_class.call(user)

    expect(rebuilt.id).to eq(digest.id)
    expect(rebuilt.content.keys).to contain_exactly("traded_on", "previous_session", "market")
    expect(rebuilt.read_at).to be_present
    expect(rebuilt.headline).to eq("NEPSE -0.91%")
  end

  it "builds nothing before the first snapshot" do
    expect(described_class.call(user)).to be_nil
  end
end
