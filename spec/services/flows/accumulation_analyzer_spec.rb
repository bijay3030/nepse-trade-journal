require "rails_helper"

RSpec.describe Flows::AccumulationAnalyzer do
  let(:stock) { create(:stock, symbol: "NABIL") }
  let(:days) { (1..20).map { Date.new(2026, 9, 1) + _1 } }

  before { Broker.create!(broker_no: "58", name: "Naasa Securities") }

  # Each day: `concentrated` brokers absorb shares from many small sellers (or the reverse),
  # at NPR 500 a share, well above the thin-trading floor.
  def trade_days(concentrated:, direction:)
    days.each do |day|
      small = (1..10).map { |n| "S#{n}" }
      concentrated.each do |broker|
        qty = 4_000
        direction == :buy ? flow(day, broker, buy: qty) : flow(day, broker, sell: qty)
      end
      small.each do |broker|
        qty = 4_000 * concentrated.size / small.size
        direction == :buy ? flow(day, broker, sell: qty) : flow(day, broker, buy: qty)
      end
    end
  end

  def flow(day, broker, buy: 0, sell: 0)
    StockBrokerFlow.create!(stock: stock, traded_on: day, broker_no: broker, buy_quantity: buy, sell_quantity: sell,
                            buy_amount: buy * 500, sell_amount: sell * 500)
  end

  it "flags accumulation when a few brokers absorb what many sell" do
    trade_days(concentrated: %w[58 45], direction: :buy)

    result = described_class.call(stock)

    expect(result).to include(state: "accumulation", sessions: 20)
    expect(result[:windows][20]).to include(top_buyers_pct: 100.0, top_sellers_pct: 50.0, score: 50.0)
    expect(result[:top_buyers].map { _1[:broker_no] }).to eq(%w[45 58])
    expect(result[:top_buyers].find { _1[:broker_no] == "58" }).to include(name: "Naasa Securities", net_quantity: 80_000, avg_buy_price: 500.0)
    expect(result[:top_sellers].size).to eq(5)
    expect(result[:daily].size).to eq(20)
    expect(result[:daily].last).to include(top_buyers_net: 8_000, volume: 8_000)
  end

  it "flags distribution when a few brokers unload onto many" do
    trade_days(concentrated: %w[58 45], direction: :sell)

    expect(described_class.call(stock)).to include(state: "distribution", score: -50.0)
  end

  it "keeps thinly traded stocks neutral and says so" do
    trade_days(concentrated: %w[58 45], direction: :buy)
    StockBrokerFlow.where(stock: stock).update_all("buy_amount = buy_quantity * 1") # NPR 1 a share: tiny turnover

    result = described_class.call(stock)

    expect(result).to include(state: "neutral", thin_trading: true, score: 50.0)
  end

  it "needs at least five sessions" do
    days.first(4).each { flow(_1, "58", buy: 10) }

    expect(described_class.call(stock)).to include(state: "no_data", sessions: 4)
  end

  it "analyses many stocks at once, up to a given session" do
    trade_days(concentrated: %w[58], direction: :buy)
    other = create(:stock)

    results = described_class.for_stocks([ stock.id, other.id ], as_of: days[9])

    expect(results.keys).to eq([ stock.id ])
    expect(results[stock.id][:sessions]).to eq(10)
  end
end
