require "rails_helper"

RSpec.describe Position do
  let(:stock) { create(:stock, last_price: 110) }
  let(:position) { create_position(stop: 92, fills: [ [ 100, 100, "2026-09-28" ], [ 106, 50, "2026-09-30" ] ]) }

  def create_position(stop:, fills:, initial_stop: stop)
    create(:user).positions.create!(stock: stock, stop_price: stop, initial_stop_price: initial_stop, target_price: 130).tap do |position|
      fills.each { |price, quantity, day, side = "buy"| position.fills.create!(side: side, price: price, quantity: quantity, traded_on: Date.parse(day)) }
    end
  end

  it "derives quantity, weighted average price and P&L from its fills" do
    expect(position).to have_attributes(quantity: 150, average_price: 102.0, opened_on: Date.new(2026, 9, 28), last_buy_on: Date.new(2026, 9, 30))
    expect(position.unrealized_pnl).to eq(1200.0)
    expect(position.unrealized_pct).to eq(7.84)
    # risk per share 102 - 92 = 10; up 8 => 0.8R
    expect(position.r_multiple).to eq(0.8)
  end

  it "counts buy and sell costs in the cost basis, risk at the stop and break-even" do
    # Buys of 10,000 and 5,300 at 0.36% commission + 0.015% SEBON.
    expect(position.cost_basis).to eq(15_357.38)
    # Selling 150 at 92: 13,800 - 49.68 - 2.07 - 25 DP.
    expect(position.open_risk).to eq(1634.13)
    expect(position.net_pnl_if_sold).to eq(1055.75)
    expect(position.break_even_price).to eq(102.94)
  end

  it "has no open risk once selling at the stop wouldn't lose money" do
    position.update!(stop_price: 104)
    expect(position.open_risk).to eq(0)
  end

  it "counts sells against the quantity" do
    position.fills.create!(side: "sell", price: 115, quantity: 50, traded_on: Date.new(2026, 10, 1))
    expect(position.reload.quantity).to eq(100)
  end

  it "is sellable two trading days after the last buy, skipping the weekend" do
    expect(position.sellable_on).to eq(Date.new(2026, 10, 2)) # Wed + 2 trading days = Fri
    position.fills.create!(side: "buy", price: 108, quantity: 10, traded_on: Date.new(2026, 10, 1)) # Thursday
    expect(position.reload.sellable_on).to eq(Date.new(2026, 10, 5)) # Monday
  end

  describe ".default_stop" do
    it "uses the setup's stop, capped at 8% below entry" do
      expect(described_class.default_stop(100, 95)).to eq(95.0)
      expect(described_class.default_stop(100, 80)).to eq(92.0)
      expect(described_class.default_stop(100, nil)).to eq(92.0)
    end
  end
end
