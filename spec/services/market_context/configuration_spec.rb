require "rails_helper"

RSpec.describe MarketContext::Configuration do
  describe "defaults" do
    subject(:config) { described_class.new }

    it "exposes liquidity, regime, and sector thresholds" do
      expect(config.high_liquidity_turnover).to eq(10_000_000.0)
      expect(config.medium_liquidity_turnover).to eq(2_500_000.0)
      expect(config.liquidity_short_window).to eq(10)
      expect(config.liquidity_medium_window).to eq(20)
      expect(config.liquidity_long_window).to eq(50)
      expect(config.trading_frequency_window).to eq(20)
      expect(config.min_trading_frequency_pct).to eq(50.0)
      expect(config.strong_regime_breadth_pct).to eq(60.0)
      expect(config.weak_regime_breadth_pct).to eq(40.0)
      expect(config.index_trend_window).to eq(20)
      expect(config.sector_trend_window).to eq(20)
      expect(config.sector_trend_threshold_pct).to eq(2.0)
    end
  end

  describe "custom values" do
    it "accepts override thresholds without hard floors" do
      config = described_class.new(
        high_liquidity_turnover: 5_000.0,
        medium_liquidity_turnover: 2_000.0,
        strong_regime_breadth_pct: 70.0,
        weak_regime_breadth_pct: 30.0,
        strong_ad_ratio: 1.5,
        weak_ad_ratio: 0.7
      )

      expect(config.high_liquidity_turnover).to eq(5_000.0)
      expect(config.medium_liquidity_turnover).to eq(2_000.0)
      expect(config.strong_regime_breadth_pct).to eq(70.0)
      expect(config.weak_regime_breadth_pct).to eq(30.0)
      expect(config.strong_ad_ratio).to eq(1.5)
      expect(config.weak_ad_ratio).to eq(0.7)
    end

    it "orders windows and clamps percentages" do
      config = described_class.new(
        liquidity_short_window: 30,
        liquidity_medium_window: 5,
        liquidity_long_window: 10,
        min_trading_frequency_pct: 150.0,
        strong_regime_breadth_pct: 140.0
      )

      expect(config.liquidity_short_window).to eq(30)
      expect(config.liquidity_medium_window).to eq(30)
      expect(config.liquidity_long_window).to eq(30)
      expect(config.min_trading_frequency_pct).to eq(100.0)
      expect(config.strong_regime_breadth_pct).to eq(100.0)
    end

    it "clamps negative thresholds to a positive floor" do
      config = described_class.new(high_liquidity_turnover: -5, medium_liquidity_turnover: 0)

      expect(config.high_liquidity_turnover).to eq(1.0)
      expect(config.medium_liquidity_turnover).to eq(1.0)
    end
  end
end
