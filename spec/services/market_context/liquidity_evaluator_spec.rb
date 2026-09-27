require "rails_helper"

RSpec.describe MarketContext::LiquidityEvaluator do
  let(:stock) { create(:stock, symbol: "LIQ") }

  def create_prices(count:, volume: 100, turnover: 1_000.0, total_trades: 10, zero_volume_days: [])
    (0...count).each do |i|
      zero = zero_volume_days.include?(i)
      create(
        :stock_daily_price,
        stock: stock,
        traded_on: Date.current - i,
        open_price: 10.0,
        high_price: 10.0,
        low_price: 10.0,
        close_price: 10.0,
        previous_close: 10.0,
        volume: zero ? 0 : volume,
        turnover: zero ? 0.0 : turnover,
        total_trades: total_trades
      )
    end
  end

  describe "#evaluate" do
    it "returns an empty low-liquidity result when there is no price history" do
      result = described_class.call(stock)

      expect(result[:rating]).to eq("low")
      expect(result[:recent_turnover]).to eq(0.0)
      expect(result[:avg_volume_20d]).to eq(0)
      expect(result[:trading_frequency_pct]).to eq(0.0)
      expect(result[:frequency_window]).to eq(0)
    end

    it "computes recent turnover, average volume, turnover, and daily trades" do
      create_prices(count: 50, volume: 200, turnover: 5_000.0, total_trades: 25)

      result = described_class.call(stock)

      expect(result[:recent_turnover]).to eq(5_000.0)
      expect(result[:recent_volume]).to eq(200)
      expect(result[:avg_volume_10d]).to eq(200)
      expect(result[:avg_volume_20d]).to eq(200)
      expect(result[:avg_volume_50d]).to eq(200)
      expect(result[:avg_turnover_20d]).to eq(5_000.0)
      expect(result[:avg_daily_trades]).to eq(25)
      expect(result[:windows]).to eq(short: 10, medium: 20, long: 50, frequency: 20)
    end

    it "computes trading frequency from sessions with non-zero volume" do
      create_prices(count: 20, zero_volume_days: (0...5).to_a)

      result = described_class.call(stock)

      expect(result[:frequency_window]).to eq(20)
      expect(result[:traded_sessions]).to eq(15)
      expect(result[:trading_frequency_pct]).to eq(75.0)
    end

    it "falls back to close price times volume when turnover is absent" do
      create(
        :stock_daily_price,
        stock: stock,
        traded_on: Date.current,
        close_price: 12.0,
        previous_close: 12.0,
        volume: 100,
        turnover: 0.0
      )

      result = described_class.call(stock)

      expect(result[:recent_turnover]).to eq(1_200.0)
      expect(result[:avg_turnover_20d]).to eq(1_200.0)
    end

    it "classifies rating against configurable turnover thresholds" do
      create_prices(count: 20, turnover: 3_000.0)
      config = MarketContext::Configuration.new(
        medium_liquidity_turnover: 2_000.0,
        high_liquidity_turnover: 5_000.0
      )

      expect(described_class.call(stock, config)[:rating]).to eq("medium")

      high_config = MarketContext::Configuration.new(
        medium_liquidity_turnover: 2_000.0,
        high_liquidity_turnover: 2_500.0
      )
      expect(described_class.call(stock, high_config)[:rating]).to eq("high")
    end

    it "respects configurable averaging windows" do
      create_prices(count: 10, volume: 100)
      create(
        :stock_daily_price,
        stock: stock,
        traded_on: Date.current - 10,
        close_price: 10.0,
        previous_close: 10.0,
        volume: 10_000,
        turnover: 10_000.0
      )

      config = MarketContext::Configuration.new(
        liquidity_short_window: 5,
        liquidity_medium_window: 5,
        liquidity_long_window: 11
      )
      result = described_class.call(stock, config)

      expect(result[:avg_volume_short]).to eq(100)
      expect(result[:avg_volume_long]).to eq(((10 * 100 + 10_000) / 11.0).round)
    end
  end

  describe "#passes?" do
    it "fails when rating is below the requested minimum" do
      create_prices(count: 20, turnover: 1_000.0)
      config = MarketContext::Configuration.new(
        medium_liquidity_turnover: 2_000.0,
        high_liquidity_turnover: 5_000.0
      )

      evaluator = described_class.new(stock, config)

      expect(evaluator.passes?(min_rating: "low")).to be true
      expect(evaluator.passes?(min_rating: "medium")).to be false
    end

    it "enforces trading frequency and average trades filters" do
      create_prices(count: 20, turnover: 10_000.0, total_trades: 5, zero_volume_days: (0...5).to_a)

      evaluator = described_class.new(stock)

      expect(evaluator.passes?(min_rating: "low")).to be true
      expect(evaluator.passes?(min_rating: "low", min_trading_frequency_pct: 80.0)).to be false
      expect(evaluator.passes?(min_rating: "low", min_avg_daily_trades: 10)).to be false
    end
  end
end
