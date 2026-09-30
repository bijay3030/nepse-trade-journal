require "rails_helper"

RSpec.describe Watchlist::EntryZoneSuggester do
  let(:stock) { create(:stock, symbol: "NABIL", last_price: 560.0) }
  let(:analysis) do
    {
      current_price: 560.0,
      setup_state: "near_pivot",
      candles: [ { traded_on: "2026-09-24" } ],
      vcp: {
        pivot_level: 570.0, setup_quality_score: 72, is_vcp_setup: true, contractions_count: 3,
        contraction_sequence_text: "12% -> 7% -> 4%", volume_behavior: "contracting",
        contractions: [ { low: 480.0 }, { low: 520.0 }, { low: 548.0 } ]
      },
      price_action: {
        trend: "uptrend", structure: "higher_highs_higher_lows",
        support_levels: [ { level: 548.0 }, { level: 520.0 }, { level: 575.0 } ],
        resistance_levels: [ { level: 640.0 }, { level: 590.0 } ]
      },
      market: { regime_status: "bullish" }
    }
  end

  before do
    allow(Stock::SetupAnalysis).to receive(:new).and_return(instance_double(Stock::SetupAnalysis, detail: analysis))
  end

  def suggest(type)
    described_class.call(stock, type, market: {})
  end

  it "puts a VCP zone from the pivot to 3% above, invalidated below the last contraction" do
    result = suggest("vcp")

    expect(result[:success]).to be(true)
    expect(result[:levels]).to include(
      entry_zone_low: 570.0, entry_zone_high: 587.1, invalidation_price: 548.0,
      stop_loss_price: 548.0, pivot_price: 570.0
    )
    # Resistance at 590 is less than 1R above the zone, so the next one (640) is the target.
    expect(result[:levels]).to include(target_price: 640.0, target_basis: "resistance")
    expect(result[:snapshot]).to include(vcp_score: 72, is_vcp_setup: true, contraction_sequence: "12% -> 7% -> 4%", market_regime: "bullish", analysed_on: "2026-09-24")
  end

  it "puts a pullback zone on the nearest support below the price" do
    result = suggest("pullback")

    expect(result[:levels]).to include(entry_zone_low: 548.0, entry_zone_high: 558.96, invalidation_price: 531.56, pivot_price: nil)
  end

  it "falls back to a 2R target when no resistance is far enough away" do
    analysis[:price_action][:resistance_levels] = []

    expect(suggest("vcp")[:levels]).to include(target_price: 614.0, target_basis: "2R") # 570 + 2 x 22
  end

  it "explains why a suggestion is not possible" do
    analysis[:vcp][:pivot_level] = nil
    expect(suggest("vcp")).to eq(success: false, error: "No VCP pivot found for NABIL. Try a pullback setup or enter levels manually.")

    analysis[:candles] = []
    expect(suggest("pullback")[:error]).to eq("NABIL has no price history to analyse yet")
    expect(suggest("swing")[:error]).to eq('Unknown setup type "swing"')
  end
end
