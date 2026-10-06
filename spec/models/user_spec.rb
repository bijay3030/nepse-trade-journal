require "rails_helper"

RSpec.describe User, "#size_position" do
  let(:user) { create(:user, trading_capital: 1_000_000, risk_per_trade_pct: 1) }

  it "adds a cautious size alongside the normal one outside an uptrend" do
    market = { state: "correction", label: "Correction", size_factor: 0.25 }
    result = user.size_position(entry: 500, stop: 460, target: 580, market: market)

    expect(result[:quantity]).to eq(230) # 10,000 risk; fees count toward it
    expect(result[:cautious]).to eq(state: "correction", label: "Correction", size_factor: 0.25, risk_budget: 2500.0, quantity: 50)
  end

  it "leaves the size alone in an uptrend or without index data" do
    expect(user.size_position(entry: 500, stop: 460, market: { state: "uptrend", size_factor: 1.0 })).not_to have_key(:cautious)
    expect(user.size_position(entry: 500, stop: 460, market: nil)).not_to have_key(:cautious)
  end
end

RSpec.describe User, "#size_position heat check" do
  let(:user) { create(:user, trading_capital: 1_000_000, risk_per_trade_pct: 1, max_open_risk_pct: 6) }

  it "reports heat now and after the buy, and the size that keeps within the limit" do
    stock = create(:stock, last_price: 100)
    user.positions.create!(stock: stock, stop_price: 92, initial_stop_price: 92).tap do |p|
      p.fills.create!(side: "buy", price: 100, quantity: 6_200, traded_on: Date.new(2026, 9, 24)) # ~5.2% at risk
    end

    heat = user.size_position(entry: 500, stop: 460, market: nil)[:heat]

    expect(heat).to include(limit_pct: 6.0, state: "over")
    expect(heat[:now_pct]).to be_within(0.2).of(5.2)
    expect(heat[:after_pct]).to be > 6
    expect(heat[:fits_quantity]).to be_between(10, 220)
  end

  it "fits the full size when there's room" do
    expect(user.size_position(entry: 500, stop: 460, market: nil)[:heat]).to include(now_pct: 0.0, state: "ok", fits_quantity: 230)
  end
end
