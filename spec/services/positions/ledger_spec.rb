require "rails_helper"

RSpec.describe Positions::Ledger do
  Fill = Struct.new(:id, :side, :price, :quantity, :traded_on) do
    def buy? = side == "buy"
  end

  def fill(id, side, price, quantity, day) = Fill.new(id, side, price, quantity, Date.parse(day))

  # Buy 100 at 100 (cost 10,037.50 with 0.36% + 0.015%) and 100 at 110; sell 150 at 130.
  let(:fills) do
    [ fill(1, "buy", 100, 100, "2026-01-05"), fill(2, "buy", 110, 100, "2026-02-05"), fill(3, "sell", 130, 150, "2026-03-05") ]
  end

  it "matches a sell to the earliest buys and taxes the gain at 10% within a year" do
    ledger = described_class.new(fills)
    sale = ledger.sales.sole
    proceeds = Nepse::Costs.net_proceeds(130, 150)
    cost = 10_037.5 + 50 * (11_000 + Nepse::Costs.buy_costs(11_000)) / 100

    expect(sale[:proceeds]).to eq(proceeds)
    expect(sale[:cost]).to be_within(0.01).of(cost)
    expect(sale[:gain]).to be_within(0.01).of(proceeds - cost)
    expect(sale[:tax]).to be_within(0.01).of((proceeds - cost) * 0.10)
    expect(ledger.open_quantity).to eq(50)
    expect(ledger.open_cost).to be_within(0.01).of(50 * (11_000 + Nepse::Costs.buy_costs(11_000)) / 100)
    expect(ledger.realized[:net]).to be_within(0.01).of((proceeds - cost) * 0.9)
  end

  it "uses 7.5% for a lot held more than 365 days and doesn't tax a loss" do
    long = described_class.new([ fill(1, "buy", 100, 100, "2025-01-05"), fill(2, "sell", 130, 100, "2026-01-10") ]).sales.sole
    expect(long[:tax]).to be_within(0.01).of(long[:gain] * 0.075)

    loss = described_class.new([ fill(1, "buy", 100, 100, "2026-01-05"), fill(2, "sell", 90, 100, "2026-01-20") ]).sales.sole
    expect(loss[:gain]).to be < 0
    expect(loss[:tax]).to eq(0.0)
  end
end
