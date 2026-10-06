require "rails_helper"

RSpec.describe Watchlist::EntryChecklist do
  let(:stock) { create(:stock, symbol: "NABIL", sector: "Commercial Banks", last_price: 505.0, change_percent: 1.2) }
  # Zone 500-515, invalidation/stop 470, target 560 => 2R.
  let(:item) { create(:watchlist_item, stock: stock) }
  let(:context) { instance_double(Watchlist::MarketContext, regime: "neutral", nepse_return: -1.2, sector_returns: { "Commercial Banks" => 0.8 }) }
  let(:vcp) do
    { is_vcp_setup: true, setup_quality_score: 80, contraction_sequence_text: "13.4% -> 5.4%", classification: "contracting_price_and_volume",
      qualification_checks: [ { label: "Volume drying up", passed: true } ] }
  end

  before do
    allow(Vcp::DetectionEngine).to receive(:call).and_return(vcp)
    StockSetupSnapshot.create!(stock: stock, traded_on: Date.new(2026, 9, 29), close_price: 505, zone_state: "in_zone", avg_turnover: 34_000_000)
    # 20 sessions with a 2% daily range around 500, and the 50-day at 490.
    20.times do |i|
      price = create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 1) + i, high_price: 505, low_price: 495.1, close_price: 500)
      StockDailyIndicator.create!(stock: stock, stock_daily_price: price, traded_on: price.traded_on, sma_50: 490) if i == 19
    end
  end

  def statuses = described_class.call(item, context: context)[:checks].to_h { [ _1[:key], _1[:status] ] }

  it "passes every check for a confirmed VCP breakout in a healthy market" do
    item.update!(last_close_on: Date.new(2026, 9, 30), last_close_state: "confirmed", last_close_price: 508, last_close_relative_volume: 1.8)

    result = described_class.call(item, context: context)

    expect(result[:checks].map { _1[:status] }).to all(eq("pass"))
    expect(result).to include(passed: 11, total: 11, all_passed: true)
    expect(result[:checks].find { _1[:key] == "sector" }[:detail]).to eq("Commercial Banks +0.80% vs NEPSE -1.20%")
  end

  it "leaves the close and volume pending until the first end-of-day check" do
    expect(statuses).to include("close" => "pending", "volume" => "pending")
    expect(described_class.call(item, context: context)[:all_passed]).to be(false)
  end

  it "explains which VCP rules are not met" do
    vcp.merge!(is_vcp_setup: false, qualification_checks: [ { label: "Volume drying up", passed: false }, { label: "Base at least 15 trading days", passed: false } ])

    pattern = described_class.call(item, context: context)[:checks].first
    expect(pattern).to include(status: "fail", detail: "Not met: Volume drying up; Base at least 15 trading days")
  end

  it "fails on a weak market, a lagging sector, poor risk:reward and a chased price" do
    weak = instance_double(Watchlist::MarketContext, regime: "weak", nepse_return: 2.0, sector_returns: { "Commercial Banks" => 0.5 })
    item.update!(target_price: 530) # 1R
    stock.update!(last_price: 520)

    result = described_class.call(item, context: weak)[:checks].to_h { [ _1[:key], _1[:status] ] }
    expect(result).to include("regime" => "fail", "sector" => "fail", "risk_reward" => "fail", "not_extended" => "fail")
  end

  it "uses trend instead of VCP rules for pullbacks and skips the volume check" do
    item.update!(setup_type: "pullback", last_close_on: Date.new(2026, 9, 30), last_close_state: "held_zone", last_close_price: 505)
    allow(PriceAction::AnalyzerService).to receive(:call).and_return({ trend: "uptrend", structure: "higher_high_higher_low" })

    expect(statuses).to include("pattern" => "pass", "close" => "pass", "volume" => "n/a")
    expect(described_class.call(item, context: context)[:total]).to eq(10)
  end

  it "marks the sector check not applicable without a sector index" do
    stock.update!(sector: "Mutual Fund")

    expect(statuses["sector"]).to eq("n/a")
  end

  it "checks the pattern and treats a base breakout like a breakout" do
    item.update!(setup_type: "base_breakout")
    allow(Setups::Patterns).to receive(:base_breakout).and_return({ success: true, details: { base_sessions: 31, base_depth_pct: 8.0 } })

    checks = described_class.call(item, context: context)[:checks].index_by { _1[:key] }

    expect(checks["pattern"]).to include(label: "Flat base near the 52-week high", status: "pass", detail: "31-session base, 8.0% deep")
    expect(checks["close"][:label]).to eq("Closed above the pivot")
    expect(checks["volume"][:status]).to eq("pending")
  end

  it "treats an MA pullback like a pullback" do
    item.update!(setup_type: "ma_pullback")
    allow(Setups::Patterns).to receive(:ma_pullback).and_return({ success: false, error: "Not an uptrend above a rising 50-day average" })

    checks = described_class.call(item, context: context)[:checks].index_by { _1[:key] }

    expect(checks["pattern"]).to include(status: "fail", detail: "Not an uptrend above a rising 50-day average")
    expect(checks["close"][:label]).to eq("Closed inside the entry zone")
    expect(checks["volume"][:status]).to eq("n/a")
  end

  describe "stretch rule" do
    def stretch = described_class.call(item, context: context)[:checks].find { _1[:key] == "stretch" }

    it "passes near the 50-day on a normal day, with the figures" do
      # 505 is 3.1% above 490 = 1.5 ADR; today +1.2% = 0.6 ADR
      expect(stretch).to include(status: "pass", detail: "1.5 ADR above the 50-day; today +0.6 ADR (ADR 2.0%)")
    end

    it "fails when the price is 4+ ADR above the 50-day or today already ran more than 1 ADR" do
      stock.update!(last_price: 535)
      expect(stretch[:status]).to eq("fail")

      stock.update!(last_price: 505, change_percent: 3.0)
      expect(stretch).to include(status: "fail", detail: /today \+1.5 ADR/)
    end
  end

  describe "liquidity and circuit rules" do
    def checks = described_class.call(item, context: context)[:checks].index_by { _1[:key] }

    it "reports turnover and today's change when both are fine" do
      expect(checks["liquidity"]).to include(status: "pass", detail: "NPR 34.0M a day")
      expect(checks["circuit"]).to include(status: "pass", detail: "+1.20% today")
    end

    it "fails thin turnover and a stock at either circuit" do
      StockSetupSnapshot.update_all(avg_turnover: 1_200_000)
      stock.update!(change_percent: 14.8)

      expect(checks["liquidity"]).to include(status: "fail", detail: "NPR 1.2M a day: thin, a small order can move the price")
      expect(checks["circuit"]).to include(status: "fail", detail: "+14.80%: at the upper circuit, few sellers; wait for another session")

      stock.update!(change_percent: -15)
      expect(checks["circuit"][:detail]).to eq("-15.00%: at the lower circuit, few buyers; exits may not fill")

      stock.update!(change_percent: 10)
      expect(checks["circuit"]).to include(status: "pass", label: "Not at the ±15% daily limit")
    end

    it "waits for the nightly snapshot before judging liquidity" do
      StockSetupSnapshot.delete_all

      expect(checks["liquidity"][:status]).to eq("pending")
    end
  end

  describe "book close rule" do
    let(:today) { Nepse::MarketHours.today }

    def book_close_check = described_class.call(item, context: context)[:checks].find { _1[:key] == "book_close" }

    it "fails when a bonus book close is within 10 days" do
      stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, cash_percent: 5, book_close_on: today + 4, source: "chukul")

      expect(book_close_check).to include(status: "fail", detail: "10.0% bonus, book close #{(today + 4).strftime('%b %-d')}")
    end

    it "passes a cash-only book close with a note, and a bonus further away" do
      stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 0, cash_percent: 12, book_close_on: today + 3, source: "chukul")
      expect(book_close_check).to include(status: "pass", detail: "Cash dividend only (12.0%), book close #{(today + 3).strftime('%b %-d')}")

      StockDividend.delete_all
      stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: today + 20, source: "chukul")
      expect(book_close_check).to include(status: "pass", detail: "None announced")
    end
  end
end
