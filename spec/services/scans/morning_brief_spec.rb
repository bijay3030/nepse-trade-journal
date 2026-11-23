require "rails_helper"

RSpec.describe Scans::MorningBrief do
  let(:session) { Date.new(2026, 11, 20) }
  let(:monday) { Time.find_zone("Asia/Kathmandu").parse("2026-11-23 08:00") }
  let(:today) { Date.new(2026, 11, 23) }
  let(:client) { instance_double(Telegram::Client, send_message: {}) }
  let!(:user) { create(:user, telegram_chat_id: "42") }

  def snapshot(symbol, close:, zone:, in_zone:, readiness:, stop: nil, target: nil)
    stock = Stock.find_by(symbol: symbol) || create(:stock, symbol: symbol, name: "#{symbol} Limited", security_type: "Equity")
    create(:stock_daily_price, stock: stock, traded_on: session, close_price: close, previous_close: close)
    StockSetupSnapshot.create!(stock: stock, traded_on: session, close_price: close, zone_state: in_zone ? "in_zone" : "too_early", in_buy_zone: in_zone,
                               readiness_score: readiness, entry_zone_low: zone.first, entry_zone_high: zone.last, invalidation_price: stop || zone.first * 0.95, target_price: target)
  end

  before do
    @ebl = snapshot("EBL", close: 714.5, zone: [ 714.37, 728.66 ], in_zone: true, readiness: 87, stop: 685.8, target: 771.52)
    @scb = snapshot("SCB", close: 677, zone: [ 675.24, 688.74 ], in_zone: true, readiness: 79)
    @mbl = snapshot("MBL", close: 269.5, zone: [ 271.09, 276.5 ], in_zone: false, readiness: 90)
    snapshot("FAR", close: 100, zone: [ 110, 112 ], in_zone: false, readiness: 95) # 10% below: not close
    MarketEvent.create!(stock: @scb.stock, source: "chukul_bonus", external_id: "scb", kind: "cash_dividend", impact: "positive", title: "SCB cash",
                        published_on: today - 30, event_on: today + 3, data: { "bonus" => 0, "cash" => 16 })
    2.times do |i|
      MarketEvent.create!(stock: @ebl.stock, source: "sharesansar", external_id: "p#{i}", kind: "promoter_sale", impact: "negative", important: true,
                          title: "EBL promoter shares", reason: "Promoter shares for sale.", published_on: today - 1 - i)
    end
    create(:watchlist_item, user: user, stock: create(:stock, symbol: "AHPC", security_type: "Equity"), entry_zone_low: 259.6, entry_zone_high: 264.79, invalidation_price: 251.81, stop_loss_price: 251.81, target_price: 290, pivot_price: 260)
    create(:stock_daily_price, stock: Stock.find_by!(symbol: "AHPC"), traded_on: session, close_price: 253.2, previous_close: 253.2)
  end

  it "sends one brief on a trading morning: entry zone, what needs a human look, and stocks close to their zone" do
    expect(described_class.deliver(now: monday, client: client)).to eq(user.id => :sent)
    expect(client).to have_received(:send_message).with("42", satisfy { |text|
      text.include?("☀️ <b>Morning brief</b> · Mon 23 Nov (from the Fri 20 Nov close)") &&
        text.include?("<b>Entry zone now</b> (2, 2 new)") &&
        text.include?("<b>EBL</b> 🆕 714.50 · zone 714.37–728.66 · stop 685.80 · target 771.52 · R:R 2.0 · ready 87") &&
        text.include?("⚠️ <b>EBL</b> (Entry zone): Bad news 22 Nov: Promoter shares for sale.") && text.scan("Promoter shares for sale.").size == 1 &&
        text.include?("⚠️ <b>SCB</b> (Entry zone): 16% cash (Rs 16 a share at Rs 100 face value) book close Thu 26 Nov") &&
        text.include?("⚠️ <b>AHPC</b> (watchlist): closed at 253.20, 0.6% above its stop 251.81.") &&
        text.include?("<b>MBL</b> 269.50 · 0.6% below zone 271.09 · ready 90") && !text.include?("FAR")
    })
    expect(described_class.deliver(now: monday + 1.hour, client: client)).to eq(user.id => :duplicate)
  end

  it "skips weekends and users who turned it off" do
    expect(described_class.deliver(now: monday - 1.day, client: client)).to eq({})
    user.update!(telegram_morning_watch: false)
    expect(described_class.deliver(now: monday, client: client)).to eq({})
  end
end
