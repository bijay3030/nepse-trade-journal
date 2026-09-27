require "rails_helper"

RSpec.describe MarketContext::Filters do
  describe ".liquid?" do
    it "delegates to the liquidity evaluator with filter thresholds" do
      stock = create(:stock, symbol: "FILTER")
      (0...20).each do |i|
        create(
          :stock_daily_price,
          stock: stock,
          traded_on: Date.current - i,
          close_price: 10.0,
          previous_close: 10.0,
          volume: 100,
          turnover: 1_000.0,
          total_trades: 5
        )
      end
      config = MarketContext::Configuration.new(
        medium_liquidity_turnover: 2_000.0,
        high_liquidity_turnover: 5_000.0
      )

      expect(described_class.liquid?(stock, min_rating: "low", config: config)).to be true
      expect(described_class.liquid?(stock, min_rating: "medium", config: config)).to be false
    end
  end

  describe "regime predicates" do
    let(:regime) do
      {
        regime_status: "neutral",
        market_breadth_pct: 52.5,
        index_trend: "uptrend"
      }
    end

    it "checks allowed regime statuses" do
      expect(described_class.regime_in?(regime)).to be true
      expect(described_class.regime_in?(regime, allowed: %w[strong])).to be false
    end

    it "checks breadth and index trend" do
      expect(described_class.market_breadth_at_least?(regime, 50.0)).to be true
      expect(described_class.market_breadth_at_least?(regime, 60.0)).to be false
      expect(described_class.index_trend_in?(regime, allowed: %w[uptrend])).to be true
      expect(described_class.index_trend_in?(regime, allowed: %w[downtrend])).to be false
    end
  end

  describe "sector predicates" do
    let(:sector) do
      {
        relative_strength_rating: "strong",
        sector_trend: "uptrend",
        sector_performance_pct: 1.8,
        relative_strength_pct: 2.4
      }
    end

    it "checks sector strength, trend, and performance" do
      expect(described_class.sector_strength_in?(sector)).to be true
      expect(described_class.sector_strength_in?(sector, allowed: %w[weak])).to be false
      expect(described_class.sector_trend_in?(sector, allowed: %w[uptrend])).to be true
      expect(described_class.sector_performance_at_least?(sector, 1.5)).to be true
      expect(described_class.sector_performance_at_least?(sector, 2.0)).to be false
      expect(described_class.relative_strength_at_least?(sector, 2.0)).to be true
      expect(described_class.relative_strength_at_least?(sector, 3.0)).to be false
    end

    it "treats missing relative strength as zero" do
      expect(described_class.relative_strength_at_least?({ relative_strength_pct: nil }, 0.1)).to be false
    end
  end
end
