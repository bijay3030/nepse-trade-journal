require "rails_helper"

RSpec.describe Setups::ReadinessHistory do
  it "returns each stock's readiness over the latest snapshot sessions, oldest first" do
    stock = create(:stock)
    other = create(:stock)
    days = (1..5).map { Date.new(2026, 9, _1) }
    days.each_with_index do |day, i|
      StockSetupSnapshot.create!(stock: stock, traded_on: day, close_price: 100, zone_state: i == 4 ? "in_zone" : "too_early",
                                 readiness_score: 40 + i * 5, in_buy_zone: i == 4)
    end
    StockSetupSnapshot.create!(stock: other, traded_on: days.last, close_price: 50, zone_state: "failed", readiness_score: 10)

    history = described_class.for_stocks([ stock.id, other.id ], sessions: 3)

    expect(history[stock.id].map { _1[:score] }).to eq([ 50, 55, 60 ])
    expect(history[stock.id].last).to eq(traded_on: "2026-09-05", score: 60, zone_state: "in_zone", in_buy_zone: true)
    expect(history[other.id].size).to eq(1)
    expect(described_class.for_stock(create(:stock))).to eq([])
  end
end
