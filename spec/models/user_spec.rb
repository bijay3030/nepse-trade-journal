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
