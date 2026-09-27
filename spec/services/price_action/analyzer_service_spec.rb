require "rails_helper"

RSpec.describe PriceAction::AnalyzerService do
  describe ".call" do
    context "with synthetic uptrend price series" do
      let(:synthetic_uptrend) do
        start_date = Date.parse("2026-01-01")
        # Base price line
        prices = [
          100, 102, 104, 101, 95, 102, 108, 115, 125, 118,
          112, 108, 114, 120, 130, 145, 138, 132, 130, 136,
          142, 150, 144, 139, 145, 152, 158, 162, 160, 165
        ]

        prices.map.with_index do |p, i|
          {
            traded_on: start_date + i.days,
            open_price: p - 1.0,
            high_price: p + 1.0,
            low_price: p - 1.0,
            close_price: p,
            volume: 5000
          }
        end
      end

      let(:config) { PriceAction::Configuration.new(swing_sensitivity: 2, sr_tolerance_pct: 3.0) }

      it "classifies uptrend structure, Higher Highs / Higher Lows, and detects traceable S/R zones" do
        result = described_class.call(synthetic_uptrend, config)

        expect(result[:structure]).to eq("higher_high_higher_low")
        expect(result[:trend]).to eq("uptrend")
        expect(result[:confidence]).to be >= 0.70

        expect(result[:swing_highs]).not_to be_empty
        expect(result[:swing_lows]).not_to be_empty

        result[:support_levels].each do |support|
          expect(support[:anchor_dates]).not_to be_empty
          expect(support[:level]).to be <= result[:current_price] * 1.02
        end
      end
    end

    context "with synthetic downtrend price series" do
      let(:synthetic_downtrend) do
        start_date = Date.parse("2026-01-01")
        # Clear Lower Highs and Lower Lows:
        # High1(210) -> Low1(170) -> High2(190) -> Low2(150) -> High3(165) -> Low3(135)
        prices = [
          195, 202, 210, 205, 190, 182, 175, 170, 178, 185,
          190, 184, 172, 160, 150, 156, 162, 165, 158, 148,
          140, 135, 142, 146, 140, 132, 128, 125, 122, 120
        ]

        prices.map.with_index do |p, i|
          {
            traded_on: start_date + i.days,
            open_price: p + 1.0,
            high_price: p + 1.0,
            low_price: p - 1.0,
            close_price: p,
            volume: 5000
          }
        end
      end

      let(:config) { PriceAction::Configuration.new(swing_sensitivity: 2) }

      it "classifies downtrend structure and Lower Highs / Lower Lows" do
        result = described_class.call(synthetic_downtrend, config)

        expect(result[:structure]).to eq("lower_high_lower_low")
        expect(result[:trend]).to eq("downtrend")
      end
    end

    context "with synthetic sideways consolidation series" do
      let(:synthetic_sideways) do
        start_date = Date.parse("2026-01-01")
        prices = [100, 115, 102, 116, 101, 115, 103, 114, 108]
        full_series = []

        5.times do |cycle|
          prices.each_with_index do |p, i|
            idx = cycle * 9 + i
            full_series << {
              traded_on: start_date + idx.days,
              open_price: p,
              high_price: p + 2.0,
              low_price: p - 2.0,
              close_price: p,
              volume: 4000
            }
          end
        end
        full_series.take(45)
      end

      let(:config) { PriceAction::Configuration.new(swing_sensitivity: 2, sr_tolerance_pct: 3.0) }

      it "detects sideways trend and multi-touch support/resistance clusters" do
        result = described_class.call(synthetic_sideways, config)

        expect(result[:trend]).to eq("sideways")
        expect(result[:support_levels]).not_to be_empty
        expect(result[:resistance_levels]).not_to be_empty

        top_resistance = result[:resistance_levels].first
        expect(top_resistance[:touch_count]).to be >= 2
      end
    end

    context "breakout proximity and distance calculation" do
      let(:synthetic_breakout_setup) do
        start_date = Date.parse("2026-01-01")
        # Highs around 120.0, current price close at 118.0
        records = (0...25).map do |i|
          p = 105.0 + (i % 3) * 3
          high_p = (i == 10 || i == 18) ? 120.0 : p + 2.0
          {
            traded_on: start_date + i.days,
            open_price: p,
            high_price: high_p,
            low_price: p - 2.0,
            close_price: i == 24 ? 118.0 : p,
            volume: 5000
          }
        end
        records
      end

      let(:config) { PriceAction::Configuration.new(swing_sensitivity: 2, breakout_tolerance_pct: 2.5) }

      it "calculates accurate breakout level and percentage distance" do
        result = described_class.call(synthetic_breakout_setup, config)

        expect(result[:breakout_level]).to eq(120.0)
        # Distance = (120 - 118) / 118 * 100 = 1.69%
        expect(result[:distance_to_breakout]).to eq(1.69)
        expect(result[:is_breakout_near]).to be true
      end
    end
  end
end
