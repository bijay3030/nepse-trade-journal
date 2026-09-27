require "rails_helper"

RSpec.describe Scanner::Configuration do
  describe "defaults" do
    subject(:config) { described_class.new }

    it "uses sensible default stage thresholds" do
      expect(config.min_liquidity_rating).to eq("medium")
      expect(config.allowed_trends).to eq(%w[uptrend])
      expect(config.require_above_sma50).to be true
      expect(config.require_above_sma200).to be false
      expect(config.min_vcp_score).to eq(50.0)
      expect(config.high_volume_rvol).to eq(1.5)
      expect(config.low_volume_rvol).to eq(0.7)
      expect(config.only_included).to be true
      expect(config.max_candidates).to be_nil
    end

    it "wires nested engine configurations" do
      expect(config.market_config).to be_a(MarketContext::Configuration)
      expect(config.vcp_config).to be_a(Vcp::Configuration)
      expect(config.price_action_config).to be_a(PriceAction::Configuration)
    end

    it "leaves optional filters disabled by default" do
      expect(config.min_avg_turnover).to be_nil
      expect(config.max_pct_below_52w_high).to be_nil
      expect(config.max_distance_to_pivot_pct).to be_nil
      expect(config.allowed_structures).to be_nil
      expect(config.allowed_regimes).to be_nil
      expect(config.allowed_sector_strengths).to be_nil
    end
  end

  describe "normalization" do
    it "normalizes list filters and numeric options" do
      config = described_class.new(
        allowed_trends: "uptrend",
        required_vcp_classifications: [ "contracting_price_and_volume" ],
        allowed_structures: "higher_high_higher_low",
        min_avg_turnover: "5000",
        min_avg_daily_trades: -3,
        max_candidates: 0,
        require_above_sma50: nil
      )

      expect(config.allowed_trends).to eq(%w[uptrend])
      expect(config.required_vcp_classifications).to eq(%w[contracting_price_and_volume])
      expect(config.allowed_structures).to eq(%w[higher_high_higher_low])
      expect(config.min_avg_turnover).to eq(5_000.0)
      expect(config.min_avg_daily_trades).to eq(0)
      expect(config.max_candidates).to eq(1)
      expect(config.require_above_sma50).to be false
    end

    it "keeps nil filters as nil" do
      config = described_class.new(allowed_trends: nil, allowed_regimes: nil)

      expect(config.allowed_trends).to be_nil
      expect(config.allowed_regimes).to be_nil
    end

    it "passes nested engine configurations through" do
      market = MarketContext::Configuration.new(medium_liquidity_turnover: 500.0)
      vcp = Vcp::Configuration.new(min_contractions: 3)
      price_action = PriceAction::Configuration.new(swing_sensitivity: 2)

      config = described_class.new(market_config: market, vcp_config: vcp, price_action_config: price_action)

      expect(config.market_config).to be(market)
      expect(config.vcp_config).to be(vcp)
      expect(config.price_action_config).to be(price_action)
    end
  end
end
