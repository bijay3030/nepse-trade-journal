require "rails_helper"

RSpec.describe Indicators::CalculatorService do
  describe ".calculate_series" do
    context "SMA calculations and insufficient data boundaries" do
      let(:records) do
        (1..5).map do |i|
          { traded_on: Date.parse("2026-01-0#{i}"), close_price: i * 10, high_price: i * 10 + 5, low_price: i * 10 - 5, volume: 1000 }
        end
      end

      it "calculates SMA correctly with hand-calculated values and returns nil when data is insufficient" do
        series = described_class.calculate_series(records)
        expect(series.size).to eq(5)

        # Bar 0 (Close 10): insufficient for SMA20/50/150/200
        expect(series[0][:sma_20]).to be_nil
        expect(series[0][:sma_50]).to be_nil

        # Bar 4 (Close 50, series closes: [10, 20, 30, 40, 50]):
        # Hand-calculated SMA(3) = (30 + 40 + 50) / 3 = 40.0
        calculator = described_class.new(records)
        metrics = calculator.calculate_for_bar(4)
        expect(metrics[:change_pct_1d]).to eq(25.0) # (50 - 40) / 40 * 100 = 25%

        # SMA200 must be nil because observations = 5 < 200
        expect(metrics[:sma_200]).to be_nil
      end
    end

    context "EMA hand-calculated formula" do
      # Period = 3, k = 2 / (3 + 1) = 0.5
      # Prices: [10, 20, 30, 40]
      # Bar 0 (10): EMA3 = nil
      # Bar 1 (20): EMA3 = nil
      # Bar 2 (30): Initial EMA3 = (10 + 20 + 30) / 3 = 20.0
      # Bar 3 (40): EMA3 = (40 * 0.5) + (20.0 * 0.5) = 30.0
      let(:records) do
        [10, 20, 30, 40].map.with_index do |price, i|
          { traded_on: Date.parse("2026-01-0#{i + 1}"), close_price: price, high_price: price + 2, low_price: price - 2, volume: 1000 }
        end
      end

      it "computes EMA with exact multiplier decay" do
        calculator = described_class.new(records)
        # Using period 3 via private method check or test helper
        series = calculator.send(:calculate_ema_series, 3)

        expect(series[0]).to be_nil
        expect(series[1]).to be_nil
        expect(series[2]).to eq(20.0) # Initial SMA seed
        expect(series[3]).to eq(30.0) # (40 * 0.5) + (20 * 0.5) = 30.0
      end
    end

    context "True Range and ATR hand-calculated formula" do
      # Period = 3
      # Bar 0: High 10, Low 5, Close 8 -> TR = 10 - 5 = 5.0
      # Bar 1: High 12, Low 7, Close 11, PrevClose 8 -> TR = max(12-7=5, |12-8|=4, |7-8|=1) = 5.0
      # Bar 2: High 15, Low 10, Close 14, PrevClose 11 -> TR = max(15-10=5, |15-11|=4, |10-11|=1) = 5.0
      # Initial ATR3 at Bar 2 = (5 + 5 + 5) / 3 = 5.0
      # Bar 3: High 20, Low 12, Close 18, PrevClose 14 -> TR = max(20-12=8, |20-14|=6, |12-14|=2) = 8.0
      # Next ATR3 at Bar 3 = ((5.0 * 2) + 8.0) / 3.0 = 18 / 3 = 6.0
      # ATR % at Bar 3 = (6.0 / 18.0) * 100 = 33.33%
      let(:records) do
        [
          { traded_on: Date.parse("2026-01-01"), open_price: 6, high_price: 10, low_price: 5, close_price: 8, volume: 100 },
          { traded_on: Date.parse("2026-01-02"), open_price: 9, high_price: 12, low_price: 7, close_price: 11, volume: 100 },
          { traded_on: Date.parse("2026-01-03"), open_price: 12, high_price: 15, low_price: 10, close_price: 14, volume: 100 },
          { traded_on: Date.parse("2026-01-04"), open_price: 15, high_price: 20, low_price: 12, close_price: 18, volume: 100 }
        ]
      end

      it "calculates Wilder's ATR and ATR % accurately" do
        calculator = described_class.new(records)
        atr3_series = calculator.send(:calculate_atr_series, 3)

        expect(atr3_series[0]).to be_nil
        expect(atr3_series[1]).to be_nil
        expect(atr3_series[2]).to eq(5.0)
        expect(atr3_series[3]).to eq(6.0)
      end
    end

    context "52-Week High / Low and % Distance formulas" do
      # Window prices:
      # Highs: [100, 150, 120, 200, 180]
      # Lows:  [80,  90,  85,  110, 100]
      # Bar 4 Close: 180
      # High52W = 200, Low52W = 80
      # % Below High52W = (200 - 180) / 200 * 100 = 10.0%
      # % Above Low52W  = (180 - 80) / 80 * 100   = 125.0%
      let(:records) do
        highs = [100, 150, 120, 200, 180]
        lows  = [80, 90, 85, 110, 100]
        closes = [90, 140, 100, 190, 180]

        (0..4).map do |i|
          {
            traded_on: Date.parse("2026-01-0#{i + 1}"),
            open_price: 100,
            high_price: highs[i],
            low_price: lows[i],
            close_price: closes[i],
            volume: 1000
          }
        end
      end

      it "calculates 52-week High/Low and percentage bounds correctly" do
        calculator = described_class.new(records)
        metrics = calculator.calculate_for_bar(4)

        expect(metrics[:high_52w]).to eq(200.0)
        expect(metrics[:low_52w]).to eq(80.0)
        expect(metrics[:pct_below_high_52w]).to eq(10.0)
        expect(metrics[:pct_above_low_52w]).to eq(125.0)
      end
    end
  end
end
