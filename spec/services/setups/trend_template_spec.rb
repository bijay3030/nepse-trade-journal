require "rails_helper"

RSpec.describe Setups::TrendTemplate do
  let(:indicator) { StockDailyIndicator.new(sma_50: 110, sma_150: 100, sma_200: 95, low_52w: 80, high_52w: 130) }
  let(:month_ago) { StockDailyIndicator.new(sma_200: 92) }

  it "passes every rule for a stage-2 uptrend" do
    result = described_class.call(close: 120, indicator: indicator, month_ago: month_ago, rs_rating: 85)

    expect(result).to include(price_rules_passed: 7, passed: 8)
    expect(result[:checks].map { _1[:key] }).to eq(%w[above_long_mas ma150_above_ma200 ma200_rising ma50_above_long above_ma50 above_52w_low near_52w_high rs_rating])
  end

  it "reports each failing rule with its detail" do
    result = described_class.call(close: 96, indicator: indicator, month_ago: StockDailyIndicator.new(sma_200: 99), rs_rating: 40)
    failing = result[:checks].reject { _1[:passed] }.map { _1[:key] }

    expect(failing).to contain_exactly("above_long_mas", "ma200_rising", "above_ma50", "above_52w_low", "near_52w_high", "rs_rating")
    expect(result[:checks].find { _1[:key] == "near_52w_high" }[:detail]).to eq("35.4% below 130.00")
  end

  it "fails moving-average rules without enough history" do
    result = described_class.call(close: 100, indicator: nil, month_ago: nil, rs_rating: nil)

    expect(result[:passed]).to eq(0)
    expect(result[:checks].first[:detail]).to eq("Not enough history")
  end
end
