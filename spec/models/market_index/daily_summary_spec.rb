require "rails_helper"

RSpec.describe MarketIndex::DailySummary do
  let(:day) { Date.new(2026, 11, 17) }
  let(:evening) { Time.find_zone("Asia/Kathmandu").parse("2026-11-17 17:15") }
  let(:nepse) { create(:market_index, symbol: "NEPSE") }

  before do
    (1..30).each { |i| create(:market_index_history, market_index: nepse, traded_on: day - 31 + i, index_value: 2600 + i, turnover: 3e9) }
    create(:market_index_history, market_index: nepse, traded_on: day, index_value: 2636.10, change_percent: -0.48, turnover: 4.7e9)

    { "UPPY" => [ 5.5, "Hydropower", 9e7 ], "DOWN" => [ -4.2, "Commercial Banks", 2e8 ], "FLAT" => [ 0, "Commercial Banks", 1e7 ],
      "THIN" => [ 9.9, "Hydropower", 1e5 ] }.each do |symbol, (change, sector, turnover)|
      stock = create(:stock, symbol: symbol, sector: sector, security_type: "Equity")
      create(:stock_daily_price, stock: stock, traded_on: day, close_price: 100 + change, previous_close: 100, change_amount: change, change_percent: change, turnover: turnover)
      StockSetupSnapshot.create!(stock: stock, traded_on: day, close_price: 100, zone_state: "in_zone", in_buy_zone: symbol == "UPPY",
                                 guards: symbol == "THIN" ? [ "thin_volume" ] : [])
    end
  end

  it "summarises the session" do
    summary = described_class.call(day)

    expect(summary).to include(index: 2636.10, change_pct: -0.48, change_points: 6.1, turnover: 4.7e9, previous_turnover: 3e9,
                               advancing: 2, declining: 1, unchanged: 1, board: { total: 1, joined: 1 })
    expect(summary[:gainers].map { _1[:symbol] }).to eq([ "UPPY" ]) # THIN is left out of the movers
    expect(summary[:losers].map { _1[:symbol] }).to eq([ "DOWN" ])
    expect(summary[:most_traded].first[:symbol]).to eq("DOWN")
    expect(summary[:sectors].map { _1[:sector] }).to eq([ "Hydropower", "Commercial Banks" ])
    expect(summary[:phase]).to include(phase: "sideways", as_of: day)

    text = Telegram::Messages.market_summary(summary)
    expect(text).to include("📊 <b>NEPSE Tue Nov 17</b>: 2636.10 ▼ -0.48% (+6.10)", "Turnover NPR 4.70 bn (3.00 bn the session before)",
                            "2 up · 1 down · 1 unchanged (A/D 2.0)", "Entry zone now: 1 stock (1 new)", "<b>Top gainers</b> (liquid): UPPY +5.50%",
                            "<b>Most traded</b>: DOWN 200M")
  end

  it "returns nothing for a session without stored prices" do
    expect(described_class.call(day - 1)).to be_nil
  end

  describe ".deliver" do
    let(:client) { instance_double(Telegram::Client, send_message: {}) }
    let!(:user) { create(:user, telegram_chat_id: "42") }

    it "sends one message per session to users who want it, only for today's session" do
      create(:user, telegram_chat_id: "43", telegram_market_summary: false)

      expect(described_class.deliver(traded_on: day, now: evening, client: client)).to eq(user.id => :sent)
      expect(described_class.deliver(traded_on: day, now: evening + 1.hour, client: client)).to eq(user.id => :duplicate)
      expect(client).to have_received(:send_message).with("42", include("📊")).once
      expect(described_class.deliver(traded_on: day - 1, now: evening, client: client)).to eq({}) # a catch-up of an old session
    end
  end
end
