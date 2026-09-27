require "rails_helper"

RSpec.describe MarketContext::RegimeEngine do
  let(:date) { Date.current }

  def create_nepse_index(values)
    index = create(:market_index, symbol: "NEPSE", name: "NEPSE Index", current_value: values.last)
    start = date - (values.size - 1)
    values.each_with_index do |value, i|
      create(:market_index_history, market_index: index, traded_on: start + i, index_value: value, change_percent: 0.5)
    end
    index
  end

  def create_stock(symbol:, change:, above_sma50:, sector: "Commercial Banks")
    stock = create(:stock, symbol: symbol, sector: sector, last_price: 100.0)
    create(
      :stock_daily_price,
      stock: stock,
      traded_on: date,
      open_price: 100.0,
      high_price: 100.0 + change.abs,
      low_price: 100.0 - change.abs,
      close_price: 100.0 + change,
      previous_close: 100.0,
      volume: 1_000,
      turnover: 1_000_000.0,
      total_trades: 10
    )
    create(
      :stock_daily_indicator,
      stock: stock,
      stock_daily_price: nil,
      traded_on: date,
      sma_50: above_sma50 ? 90.0 : 110.0,
      sma_200: 90.0
    )
    stock
  end

  describe "#evaluate" do
    it "classifies a broad, rising market as strong" do
      create_nepse_index((0..24).map { |i| 1_000.0 + (i * 10) })
      10.times { |i| create_stock(symbol: "ADV#{i}", change: 5, above_sma50: true) }

      result = described_class.call(date)

      expect(result[:regime_status]).to eq("strong")
      expect(result[:index_trend]).to eq("uptrend")
      expect(result[:index_sma20]).to eq(((1_050.0 + 1_240.0) / 2.0).round(2))
      expect(result[:advancing_stocks]).to eq(10)
      expect(result[:declining_stocks]).to eq(0)
      expect(result[:market_breadth_pct]).to eq(100.0)
      expect(result[:breadth_rating]).to eq("strong")
      expect(result[:regime_basis][:strong_breadth]).to be true
    end

    it "classifies a mixed market as neutral" do
      create_nepse_index((0..24).map { |i| 1_000.0 + (i * 10) })
      5.times { |i| create_stock(symbol: "UP#{i}", change: 5, above_sma50: true) }
      5.times { |i| create_stock(symbol: "DOWN#{i}", change: -5, above_sma50: false) }

      result = described_class.call(date)

      expect(result[:regime_status]).to eq("neutral")
      expect(result[:advance_decline_ratio]).to eq(1.0)
      expect(result[:market_breadth_pct]).to eq(50.0)
      expect(result[:breadth_rating]).to eq("neutral")
    end

    it "classifies a weak-breadth market as weak" do
      create_nepse_index((0..24).map { |i| 1_000.0 + (i * 10) })
      2.times { |i| create_stock(symbol: "FEWUP#{i}", change: 5, above_sma50: true) }
      8.times { |i| create_stock(symbol: "MANYDOWN#{i}", change: -5, above_sma50: false) }

      result = described_class.call(date)

      expect(result[:regime_status]).to eq("weak")
      expect(result[:regime_basis][:weak_breadth]).to be true
    end

    it "classifies a downtrending index as weak" do
      create_nepse_index((0..24).map { |i| 1_240.0 - (i * 10) })
      10.times { |i| create_stock(symbol: "RISER#{i}", change: 5, above_sma50: true) }

      result = described_class.call(date)

      expect(result[:index_trend]).to eq("downtrend")
      expect(result[:regime_status]).to eq("weak")
      expect(result[:regime_basis][:downtrend]).to be true
    end

    it "honours configurable regime thresholds" do
      create_nepse_index((0..24).map { |i| 1_000.0 + (i * 10) })
      6.times { |i| create_stock(symbol: "SIXUP#{i}", change: 5, above_sma50: true) }
      4.times { |i| create_stock(symbol: "FOURDN#{i}", change: -5, above_sma50: false) }

      relaxed = MarketContext::Configuration.new(
        strong_regime_breadth_pct: 55.0,
        weak_regime_breadth_pct: 20.0,
        strong_ad_ratio: 1.0
      )

      expect(described_class.call(date, relaxed)[:regime_status]).to eq("strong")
    end

    it "returns zeroed metrics when no market data exists" do
      result = described_class.call(date)

      expect(result[:regime_status]).to eq("weak")
      expect(result[:nepse_index]).to eq(0.0)
      expect(result[:market_turnover]).to eq(0.0)
      expect(result[:advancing_stocks]).to eq(0)
      expect(result[:declining_stocks]).to eq(0)
      expect(result[:market_breadth_pct]).to eq(0.0)
      expect(result[:total_stocks_audited]).to eq(0)
    end
  end
end
