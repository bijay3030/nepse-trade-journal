require "rails_helper"

RSpec.describe MarketContext::SectorAnalyzer do
  let(:date) { Date.current }
  let(:config) do
    MarketContext::Configuration.new(
      sector_trend_window: 5,
      sector_trend_threshold_pct: 2.0,
      sector_strong_relative_strength_pct: 1.0,
      sector_weak_relative_strength_pct: -1.0
    )
  end

  def create_series(stock, closes, last_date: date)
    start = last_date - (closes.size - 1)
    closes.each_with_index do |close, i|
      previous = i.zero? ? close : closes[i - 1]
      create(
        :stock_daily_price,
        stock: stock,
        traded_on: start + i,
        open_price: close,
        high_price: close,
        low_price: close,
        close_price: close,
        previous_close: previous,
        volume: 1_000,
        turnover: close * 1_000,
        total_trades: 10
      )
    end
  end

  describe "#evaluate" do
    it "returns an empty result for a sector with no constituents" do
      result = described_class.call("Unknown Sector", date: date, config: config)

      expect(result[:constituents_count]).to eq(0)
      expect(result[:relative_strength_rating]).to eq("neutral")
      expect(result[:sector_trend]).to eq("sideways")
    end

    it "computes sector performance, trend, and relative strength" do
      sector_stocks = Array.new(3) { |i| create(:stock, symbol: "BANK#{i}", sector: "Commercial Banks", last_price: 108.0) }
      market_stocks = Array.new(2) { |i| create(:stock, symbol: "HYDRO#{i}", sector: "Hydropower", last_price: 100.0) }

      sector_stocks.each { |stock| create_series(stock, [ 100, 102, 104, 106, 108 ]) }
      market_stocks.each { |stock| create_series(stock, [ 100, 100, 100, 100, 100 ]) }

      result = described_class.call("Commercial Banks", date: date, config: config)

      expect(result[:constituents_count]).to eq(3)
      expect(result[:advancing_stocks]).to eq(3)
      expect(result[:declining_stocks]).to eq(0)
      expect(result[:sector_performance_pct]).to be > 0
      expect(result[:sector_cumulative_return_pct]).to eq(8.0)
      expect(result[:market_cumulative_return_pct]).to eq(4.8)
      expect(result[:relative_strength_pct]).to eq(3.2)
      expect(result[:relative_strength_rating]).to eq("strong")
      expect(result[:sector_trend]).to eq("uptrend")
      expect(result[:sector_turnover]).to eq(108.0 * 1_000 * 3)
    end

    it "classifies a flat sector as sideways and neutral" do
      stocks = Array.new(3) { |i| create(:stock, symbol: "FLAT#{i}", sector: "Life Insurance", last_price: 100.0) }
      stocks.each { |stock| create_series(stock, [ 100, 100, 100, 100, 100 ]) }

      result = described_class.call("Life Insurance", date: date, config: config)

      expect(result[:sector_trend]).to eq("sideways")
      expect(result[:relative_strength_pct]).to eq(0.0)
      expect(result[:relative_strength_rating]).to eq("neutral")
    end

    it "flags a declining sector underperforming the market as weak" do
      sector_stocks = Array.new(3) { |i| create(:stock, symbol: "WEAK#{i}", sector: "Microfinance", last_price: 92.0) }
      market_stocks = Array.new(2) { |i| create(:stock, symbol: "STRONG#{i}", sector: "Development Banks", last_price: 108.0) }

      sector_stocks.each { |stock| create_series(stock, [ 100, 98, 96, 94, 92 ]) }
      market_stocks.each { |stock| create_series(stock, [ 100, 102, 104, 106, 108 ]) }

      result = described_class.call("Microfinance", date: date, config: config)

      expect(result[:sector_trend]).to eq("downtrend")
      expect(result[:relative_strength_pct]).to be < 0
      expect(result[:relative_strength_rating]).to eq("weak")
    end

    it "computes sector breadth from daily indicators when available" do
      stocks = Array.new(2) { |i| create(:stock, symbol: "BREADTH#{i}", sector: "Hotels And Tourism", last_price: 100.0) }
      stocks.each { |stock| create_series(stock, [ 90, 100 ]) }
      create(:stock_daily_indicator, stock: stocks[0], stock_daily_price: nil, traded_on: date, sma_50: 90.0, sma_200: 80.0)
      create(:stock_daily_indicator, stock: stocks[1], stock_daily_price: nil, traded_on: date, sma_50: 110.0, sma_200: 80.0)

      result = described_class.call("Hotels And Tourism", date: date, config: config)

      expect(result[:pct_above_sma50]).to eq(50.0)
      expect(result[:pct_above_sma200]).to eq(100.0)
    end

    it "can resolve the sector from a stock" do
      stock = create(:stock, symbol: "BYSTOCK", sector: "Finance")
      create_series(stock, [ 100, 100 ])

      result = described_class.for_stock(stock, date: date, config: config)

      expect(result[:sector]).to eq("Finance")
      expect(result[:constituents_count]).to eq(1)
    end
  end
end
