require "rails_helper"

RSpec.describe Setups::Readiness do
  it "adds the weighted components" do
    result = described_class.call(trend_passed: 8, setup_quality: 100, regime: "strong", sector_return: 5.0, nepse_return: 1.0)

    expect(result[:score]).to eq(100)
    expect(result[:components]).to include(trend: { points: 35, max: 35 }, setup: { points: 30, max: 30 },
                                           market: { points: 15, max: 15 }, sector: { points: 20, max: 20 }, sector_vs_nepse: 4.0)
  end

  it "scales sector strength between -3 and +3 points against NEPSE" do
    at = ->(relative) { described_class.call(trend_passed: 0, setup_quality: 0, regime: "weak", sector_return: relative, nepse_return: 0.0)[:components][:sector][:points] }

    expect([ at.(-4), at.(-3), at.(0), at.(1.5), at.(3) ]).to eq([ 0, 0, 10, 15, 20 ])
  end

  it "gives half the sector points when there is no sector index" do
    result = described_class.call(trend_passed: 4, setup_quality: 50, regime: "neutral", sector_return: nil, nepse_return: 1.0)

    expect(result[:components][:sector][:points]).to eq(10)
    expect(result[:score]).to eq(18 + 15 + 9 + 10)
  end

  it "requires the zone, five trend rules and 60+ readiness for the buy zone" do
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 5, score: 60)).to be(true)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 4, score: 80)).to be(false)
    expect(described_class.in_buy_zone?(zone_state: "extended", price_rules_passed: 7, score: 90)).to be(false)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 7, score: 59)).to be(false)
  end
end
