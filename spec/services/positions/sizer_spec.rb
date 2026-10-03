require "rails_helper"

RSpec.describe Positions::Sizer do
  it "sizes so the loss at the stop, after costs, stays within the risk budget, in 10-share lots" do
    result = described_class.call(capital: 500_000, risk_pct: 1, entry: 505, stop: 470, target: 560)

    # 5,000 / 35 = 142 shares gross; costs push the loss over budget until 120.
    expect(result).to include(risk_budget: 5000.0, limited_by: "risk", quantity: 120, amount: 60_600.0, total_cost: 60_809.07,
                              loss_at_stop: 4628.65, loss_pct_of_capital: 0.93, break_even: 508.71, gain_at_target: 6134.09, reward_risk: 1.33)
    expect(result[:buy_costs]).to eq(amount: 60_600.0, commission: 199.98, sebon: 9.09, dp: 0.0, total: 209.07)
    expect(result[:loss_at_stop]).to be <= 5000
  end

  it "is limited by capital when a tight stop would need more money than there is" do
    result = described_class.call(capital: 50_000, risk_pct: 2, entry: 500, stop: 495)

    expect(result).to include(limited_by: "capital", quantity: 90)
    expect(result[:total_cost]).to be <= 50_000
  end

  it "suggests nothing when one lot already risks too much, and explains bad input" do
    expect(described_class.call(capital: 20_000, risk_pct: 1, entry: 505, stop: 470)).to include(quantity: 0, note: /smaller than the loss on one 10-share lot/)
    expect(described_class.call(capital: nil, risk_pct: 1, entry: 505, stop: 470)).to eq(error: "Set your trading capital and risk per trade in Settings")
    expect(described_class.call(capital: 500_000, risk_pct: 1, entry: 505, stop: 510)).to eq(error: "The stop must be below the entry price")
  end
end
