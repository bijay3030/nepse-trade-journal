require "rails_helper"

RSpec.describe Nepse::Costs do
  it "uses SEBON's commission slabs by transaction value" do
    expect(described_class.commission_rate(50_000)).to eq(0.0036)
    expect(described_class.commission_rate(50_001)).to eq(0.0033)
    expect(described_class.commission_rate(2_000_000)).to eq(0.00306)
    expect(described_class.commission_rate(5_000_000)).to eq(0.0027)
    expect(described_class.commission_rate(20_000_000)).to eq(0.00243)
  end

  it "adds the SEBON fee on both sides and the DP charge on sells" do
    expect(described_class.breakdown(100_000, side: :buy)).to eq(amount: 100_000.0, commission: 330.0, sebon: 15.0, dp: 0.0, total: 345.0)
    expect(described_class.breakdown(100_000, side: :sell)).to eq(amount: 100_000.0, commission: 330.0, sebon: 15.0, dp: 25.0, total: 370.0)
    expect(described_class.net_proceeds(500, 200)).to eq(99_630.0)
  end

  it "finds the sell price that covers the full cost" do
    cost = 100_000 + described_class.buy_costs(100_000) # 200 shares at 500
    break_even = described_class.break_even_price(cost, 200)

    expect(break_even).to eq(503.59)
    expect(described_class.net_proceeds(break_even, 200)).to be_within(1).of(cost)
    expect(described_class.break_even_price(cost, 0)).to be_nil
  end
end
