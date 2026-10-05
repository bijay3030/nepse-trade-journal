require "rails_helper"

RSpec.describe Setups::Readiness do
  def score(**overrides)
    described_class.call(trend_passed: 0, setup_quality: 0, regime: "weak", sector_return: 0.0, nepse_return: 0.0, flow_score: 0.0, **overrides)
  end

  it "adds the weighted components" do
    result = described_class.call(trend_passed: 8, setup_quality: 100, regime: "strong", sector_return: 5.0, nepse_return: 1.0, flow_score: 25.0, rs_rating: 80)

    expect(result[:score]).to eq(100)
    expect(result[:components]).to include(
      trend: { points: 30, max: 30 }, rs: { points: 20, max: 20 }, setup: { points: 20, max: 20 },
      flow: { points: 15, max: 15 }, sector: { points: 10, max: 10 }, market: { points: 5, max: 5 },
      sector_vs_nepse: 4.0, flow_score: 25.0
    )
  end

  it "scores RS from 40 to full at 70-89, a little less for 90+, and half without a rating" do
    at = ->(rating) { score(rs_rating: rating)[:components][:rs][:points] }

    expect([ at.(30), at.(40), at.(55), at.(70), at.(89), at.(95), at.(nil) ]).to eq([ 0, 0, 10, 20, 20, 15, 10 ])
  end

  it "scales sector strength between -3 and +3 points against NEPSE" do
    at = ->(relative) { score(sector_return: relative)[:components][:sector][:points] }

    expect([ at.(-4), at.(-3), at.(0), at.(1.5), at.(3) ]).to eq([ 0, 0, 5, 8, 10 ])
  end

  it "scales broker flow between -20 and +20" do
    at = ->(flow) { score(flow_score: flow)[:components][:flow][:points] }

    expect([ at.(-30), at.(-20), at.(0), at.(10), at.(20) ]).to eq([ 0, 0, 8, 11, 15 ])
  end

  it "gives half points when there is no sector index or flow data" do
    result = described_class.call(trend_passed: 4, setup_quality: 50, regime: "neutral", sector_return: nil, nepse_return: 1.0, flow_score: nil)

    expect(result[:components]).to include(sector: { points: 5, max: 10 }, flow: { points: 7, max: 15 }, market: { points: 3, max: 5 })
    # trend 15 + rs 10 (no rating) + setup 10 + flow 7 + sector 5 + market 3
    expect(result[:score]).to eq(15 + 10 + 10 + 7 + 5 + 3)
  end

  it "requires the zone, five trend rules and 60+ readiness for the entry zone" do
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 5, score: 60)).to be(true)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 4, score: 80)).to be(false)
    expect(described_class.in_buy_zone?(zone_state: "extended", price_rules_passed: 7, score: 90)).to be(false)
    expect(described_class.in_buy_zone?(zone_state: "in_zone", price_rules_passed: 7, score: 59)).to be(false)
  end
end
