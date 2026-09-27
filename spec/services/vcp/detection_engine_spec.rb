require "rails_helper"

RSpec.describe Vcp::DetectionEngine do
  let(:config) do
    Vcp::Configuration.new(
      swing_sensitivity: 2,
      min_base_duration_bars: 15,
      max_t1_contraction_pct: 35.0,
      max_final_contraction_pct: 10.0,
      pivot_proximity_pct: 3.0
    )
  end

  describe ".call" do
    context "1. Clear contraction (Ideal VCP)" do
      let(:synthetic_clear_vcp) do
        start_date = Date.parse("2026-01-01")
        # Synthesize T1 (18% depth, high vol), T2 (10% depth, med vol), T3 (5% depth, low vol)
        # T1: High 200 (bar 4), Low 164 (bar 8)
        # T2: High 190 (bar 14), Low 171 (bar 18)
        # T3: High 185 (bar 24), Low 176 (bar 28)
        highs = [180, 185, 192, 198, 200, 192, 184, 172, 164, 172, 180, 186, 189, 190, 184, 178, 172, 171, 176, 181, 184, 185, 182, 178, 176, 179, 182, 184]
        vols  = [100, 120, 150, 180, 200, 180, 160, 140, 120, 110, 100,  90,  85,  80,  75,  70,  65,  60,  55,  50,  45,  40,  35,  30,  25,  20,  18,  15]

        highs.map.with_index do |h, i|
          l = h - (i < 10 ? 8 : (i < 20 ? 5 : 3))
          c = (h + l) / 2.0
          {
            traded_on: start_date + i.days,
            open_price: c - 1.0,
            high_price: h.to_f,
            low_price: l.to_f,
            close_price: c,
            volume: vols[i] * 100
          }
        end
      end

      it "identifies ideal VCP setup with shrinking price contractions and volume" do
        result = described_class.call(synthetic_clear_vcp, config)

        expect(result[:is_vcp_setup]).to be true
        expect(result[:classification]).to eq("contracting_price_and_volume")
        expect(result[:volume_behavior]).to eq("contracting")
        expect(result[:setup_quality_score]).to be >= 60
        expect(result[:contractions_count]).to be >= 2

        # Verify contraction sequence text
        expect(result[:contraction_sequence_text]).to include("%")
      end
    end

    context "2. No contraction (Random price action)" do
      let(:synthetic_no_pattern) do
        start_date = Date.parse("2026-01-01")
        (0...30).map do |i|
          p = 100.0 + (i % 2 == 0 ? 5 : -5)
          {
            traded_on: start_date + i.days,
            open_price: p,
            high_price: p + 1.0,
            low_price: p - 1.0,
            close_price: p,
            volume: 1000
          }
        end
      end

      it "classifies no_pattern and returns is_vcp_setup false" do
        result = described_class.call(synthetic_no_pattern, config)

        expect(result[:is_vcp_setup]).to be false
        expect(result[:classification]).to eq("no_pattern")
      end
    end

    context "3. Increasing contractions (Expanding volatility)" do
      let(:synthetic_expanding) do
        start_date = Date.parse("2026-01-01")
        # Contractions expand: T1 (5%), T2 (12%), T3 (20%)
        # T1: High 105 (bar 3), Low 100 (bar 6)
        # T2: High 115 (bar 12), Low 101 (bar 16)
        # T3: High 130 (bar 22), Low 104 (bar 26)
        prices = [100, 103, 105, 104, 102, 100, 103, 108, 112, 115, 110, 105, 101, 106, 114, 122, 130, 120, 112, 104, 110, 118, 124]

        prices.map.with_index do |p, i|
          {
            traded_on: start_date + i.days,
            open_price: p,
            high_price: p + 2.0,
            low_price: p - 2.0,
            close_price: p,
            volume: 2000
          }
        end
      end

      it "classifies expanding_price and rejects VCP setup" do
        result = described_class.call(synthetic_expanding, config)

        expect(result[:is_vcp_setup]).to be false
        expect(result[:classification]).to eq("expanding_price")
      end
    end

    context "4. Price contraction but increasing volume" do
      let(:synthetic_increasing_vol) do
        start_date = Date.parse("2026-01-01")
        highs = [180, 185, 192, 198, 200, 192, 184, 172, 164, 172, 180, 186, 189, 190, 184, 178, 172, 171, 176, 181, 184, 185, 182, 178, 176, 179, 182, 184]
        # Volume INCREASES over time: 10 -> 200
        vols  = [ 10,  15,  20,  25,  30,  35,  40,  45,  50,  60,  70,  80,  90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240]

        highs.map.with_index do |h, i|
          l = h - (i < 10 ? 8 : (i < 20 ? 5 : 3))
          c = (h + l) / 2.0
          {
            traded_on: start_date + i.days,
            open_price: c,
            high_price: h.to_f,
            low_price: l.to_f,
            close_price: c,
            volume: vols[i] * 100
          }
        end
      end

      it "classifies contracting_price_increasing_volume and rejects setup" do
        result = described_class.call(synthetic_increasing_vol, config)

        expect(result[:classification]).to eq("contracting_price_increasing_volume")
        expect(result[:is_vcp_setup]).to be false
      end
    end

    context "5. Insufficient history" do
      let(:short_series) do
        (0...5).map do |i|
          { traded_on: Date.parse("2026-01-01") + i.days, close_price: 100 + i, high_price: 102 + i, low_price: 98 + i, volume: 1000 }
        end
      end

      it "classifies insufficient_history when observations < min_base_duration_bars" do
        result = described_class.call(short_series, config)

        expect(result[:is_vcp_setup]).to be false
        expect(result[:classification]).to eq("insufficient_history")
      end
    end

    context "6. Highly volatile stock" do
      let(:synthetic_volatile) do
        start_date = Date.parse("2026-01-01")
        # Contraction depth > 40% (exceeds max_t1_contraction_pct threshold of 35%)
        # T1 High = 200, Low = 100 (50% depth)
        prices = [120, 150, 180, 200, 160, 130, 100, 130, 160, 180, 170, 160, 150, 140, 150, 160, 170, 165, 160, 155]

        prices.map.with_index do |p, i|
          {
            traded_on: start_date + i.days,
            open_price: p,
            high_price: i == 3 ? 200.0 : p + 2.0,
            low_price: i == 6 ? 100.0 : p - 2.0,
            close_price: p,
            volume: 2000
          }
        end
      end

      it "classifies failed_contraction due to excessive volatility" do
        result = described_class.call(synthetic_volatile, config)

        expect(result[:is_vcp_setup]).to be false
        expect(result[:classification]).to eq("failed_contraction")
      end
    end

    context "7. Flat stock" do
      let(:synthetic_flat) do
        start_date = Date.parse("2026-01-01")
        (0...25).map do |i|
          {
            traded_on: start_date + i.days,
            open_price: 100.0,
            high_price: 100.0,
            low_price: 100.0,
            close_price: 100.0,
            volume: 0
          }
        end
      end

      it "handles zero volatility flat stock and returns is_vcp_setup false" do
        result = described_class.call(synthetic_flat, config)

        expect(result[:is_vcp_setup]).to be false
        expect(result[:setup_quality_score]).to eq(0)
      end
    end

    context "8. Failed breakout" do
      let(:synthetic_failed_breakout) do
        start_date = Date.parse("2026-01-01")
        # Base high 200, base low 180, but current price drops to 150 (below base low)
        prices = [185, 190, 200, 195, 188, 182, 180, 185, 192, 198, 190, 185, 170, 160, 150]

        prices.map.with_index do |p, i|
          {
            traded_on: start_date + i.days,
            open_price: p,
            high_price: p + 2.0,
            low_price: p - 2.0,
            close_price: p,
            volume: 3000
          }
        end
      end

      it "classifies failed_contraction when price breaks down below base low" do
        result = described_class.call(synthetic_failed_breakout, config)

        expect(result[:is_vcp_setup]).to be false
        expect(result[:classification]).to eq("failed_contraction")
        expect(result[:reason]).to include("broke down below base low")
      end
    end
  end
end
