require "rails_helper"

RSpec.describe Positions::Portfolio do
  let(:user) { create(:user, trading_capital: 1_000_000, max_open_risk_pct: 6, max_sector_pct: 30) }
  let(:bank) { create(:stock, symbol: "NABIL", sector: "Commercial Banks", last_price: 110) }
  let(:hydro) { create(:stock, symbol: "UPPER", sector: "Hydro Power", last_price: 200) }

  def hold(stock, price:, quantity:, stop:)
    user.positions.create!(stock: stock, stop_price: stop, initial_stop_price: stop).tap do |p|
      p.fills.create!(side: "buy", price: price, quantity: quantity, traded_on: Date.new(2026, 9, 24))
    end
  end

  it "measures heat against the limit, cash, and value per sector" do
    a = hold(bank, price: 100, quantity: 3_000, stop: 92)   # ~25k at risk, 330k value
    b = hold(hydro, price: 200, quantity: 500, stop: 184)   # ~8.7k at risk, 100k value

    result = described_class.call(user)

    expect(result[:open_risk]).to eq((a.open_risk + b.open_risk).round(2))
    expect(result[:heat]).to include(limit_pct: 6.0, state: "ok")
    expect(result[:heat][:pct]).to be_within(0.01).of(result[:open_risk] / 10_000)
    expect(result[:cash]).to eq((1_000_000 - a.cost_basis - b.cost_basis).round(2))
    expect(result[:sectors].first).to include(sector: "Commercial Banks", value: 330_000.0, pct: 33.0, symbols: [ "NABIL" ], over: true)
    expect(result[:sectors].last).to include(sector: "Hydropower", pct: 10.0, over: false)
    expect(result[:positions].map { _1[:symbol] }).to eq(%w[NABIL UPPER])
  end

  it "calls heat near from 80% of the limit and over above it" do
    hold(bank, price: 100, quantity: 6_000, stop: 92) # ~50k = 5%
    expect(described_class.call(user)[:heat][:state]).to eq("near")

    expect(described_class.heat_for(user, extra_risk: 15_000)).to include(state: "over")
  end

  it "has no heat without trading capital" do
    user.update!(trading_capital: nil)
    expect(described_class.call(user)[:heat]).to include(pct: nil, state: "unknown")
  end
end
