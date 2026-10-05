require "rails_helper"

RSpec.describe Setups::Readiness do
  def score(**overrides)
    described_class.call(trend_passed: 0, setup_quality: 0, regime: "weak", sector_return: 0.0, nepse_return: 0.0, flow_score: 0.0, **overrides)
  end

  it "adds the weighted components" do
    result = described_class.call(trend_passed: 8, setup_quality: 100, regime: "strong", sector_return: 5.0, nepse_return: 1.0, flow_score: 25.0)

    expect(result[:score]).to eq(100)
    expect(result[:components]).to include(
      trend: { points: 30, max: 30 }, setup: { points: 25, max: 25 }, market: { points: 15, max: 15 },
      sector: { points: 15, max: 15 }, flow: { points: 15, max: 15 }, sector_vs_nepse: 4.0, flow_score: 25.0
    )
  end

  it "scales sector strength between -3 and +3 points against NEPSE" do
    at = ->(relative) { score(sector_return: relative)[:components][:sector][:points] }

    expect([ at.(-4), at.(-3), at.(0), at.(1.5), at.(3) ]).to eq([ 0, 0, 8, 11, 15 ])
  end

  it "scales broker flow between -20 and +20" do
    at = ->(flow) { score(flow_score: flow)[:components][:flow][:points] }

    expect([ at.(-30), at.(-20), at.(0), at.(10), at.(20) ]).to eq([ 0, 0, 8, 11, 15 ])
  end

  it "gives half points when there is no sector index or flow data" do
    result = described_class.call(trend_passed: 4, setup_quality: 50, regime: "neutral", sector_return: nil, nepse_return: 1.0, flow_score: nil)

    expect(result[:components]).to include(sector: { points: 7, max: 15 }, flow: { points: 7, max: 15 })
    expect(result[:score]).to eq(15 + 13 + 9 + 7 + 7)
  end

  it "requires the zone, five trend rules and 60+ readiness for the entry zone" do
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 5, score: 60, setup_type: "vcp")).to be(true)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 4, score: 80, setup_type: "vcp")).to be(false)
    expect(described_class.in_buy_zone?(zone_state: "extended", price_rules_passed: 7, score: 90, setup_type: "vcp")).to be(false)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 7, score: 59, setup_type: "vcp")).to be(false)
  end

  it "keeps support pullbacks off the board but not pullbacks to a rising average" do
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 7, score: 90, setup_type: "pullback")).to be(false)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 7, score: 90, setup_type: "ma_pullback")).to be(true)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 7, score: 90, setup_type: "base_breakout")).to be(true)
  end
end
