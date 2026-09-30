require "rails_helper"

RSpec.describe Setups::RsLine do
  let(:stock) { create(:stock) }
  let(:nepse) { create(:market_index, symbol: "NEPSE") }
  let(:start) { Date.new(2026, 6, 1) }

  # closes and index values per session, same length
  def history(closes, index)
    closes.each_with_index do |close, i|
      create(:stock_daily_price, stock: stock, traded_on: start + i, close_price: close)
      create(:market_index_history, market_index: nepse, traded_on: start + i, index_value: index[i]) if index[i]
    end
  end

  it "scales the stock/NEPSE ratio to 100 at the first point and measures the change over 20 and 60 sessions" do
    history(Array.new(70) { |i| 100.0 + i }, Array.new(70) { 1000.0 })

    result = described_class.call(stock, sessions: 50)

    expect(result[:points].size).to eq(50)
    expect(result[:points].first).to include(traded_on: (start + 20).iso8601, value: 100.0)
    expect(result[:points].last[:value]).to eq((169.0 / 120 * 100).round(2))
    expect(result[:change]).to eq(20 => ((169.0 / 149 - 1) * 100).round(2), 60 => ((169.0 / 109 - 1) * 100).round(2))
  end

  it "marks new RS highs and whether RS led price there" do
    # Price flat at 100 after a 120 peak; the index falls, so RS climbs to new highs while price stays below its high.
    closes = [ 120.0 ] + Array.new(29) { 100.0 }
    index = Array.new(25) { 1000.0 } + [ 900.0, 850.0, 800.0, 780.0, 760.0 ]
    history(closes, index)

    result = described_class.call(stock)
    highs = result[:points].select { _1[:new_high] }

    expect(highs.map { _1[:traded_on] }).to eq((27..29).map { (start + _1).iso8601 }) # 100/800 first beats the 120/1000 peak
    expect(highs).to all(include(leads_price: true))
    expect(result).to include(last_new_high_on: (start + 29).iso8601, last_new_high_leads_price: true)
  end

  it "needs at least 20 prior sessions before calling a new high, and skips sessions without an index value" do
    history(Array.new(15) { |i| 100.0 + i }, Array.new(15) { |i| i == 3 ? nil : 1000.0 })

    result = described_class.call(stock)

    expect(result[:points].size).to eq(14)
    expect(result[:points].none? { _1[:new_high] }).to be(true)
    expect(result[:change]).to eq(20 => nil, 60 => nil)
  end

  it "returns an empty line without data" do
    expect(described_class.call(stock)).to include(points: [], last_new_high_on: nil)
  end
end
