require "rails_helper"

RSpec.describe Setups::Extension do
  Bar = Struct.new(:high_price, :low_price, :close_price)

  # 20 bars with a 2% daily range (high 102, low 100) closing at the given prices.
  def bars(closes) = closes.map { Bar.new(_1 * 1.01, _1 * 0.99, _1) }

  it "measures ADR, extension from the 50-day and the day's move in ADRs" do
    result = described_class.call(bars: bars(Array.new(19) { 100.0 } + [ 103.0 ]), sma_50: 90.0)

    expect(result[:adr_pct]).to be_within(0.01).of(2.02)
    # 103 is 14.4% above 90 = about 7.1 ADR; today +3% = about 1.5 ADR
    expect(result[:extension_adr]).to be_within(0.05).of(7.13)
    expect(result[:day_move_adr]).to be_within(0.05).of(1.49)
    expect(result[:flags]).to eq(%w[extended big_move])
  end

  it "counts sessions since the first close above the pivot, and flags a stale breakout" do
    closes = Array.new(14) { 98.0 } + [ 101.0, 102.0, 103.0, 102.0, 104.0, 105.0 ]
    result = described_class.call(bars: bars(closes), sma_50: 100.0, pivot: 100.0, breakout: true)

    expect(result[:breakout_age]).to eq(5)
    expect(result[:flags]).to include("stale_breakout")
    expect(described_class.call(bars: bars(closes.first(15)), sma_50: 100.0, pivot: 100.0, breakout: true)[:breakout_age]).to eq(0)
    expect(described_class.call(bars: bars(closes.first(14)), sma_50: 100.0, pivot: 100.0, breakout: true)[:breakout_age]).to be_nil
  end

  it "leaves out what it can't measure and doesn't age non-breakout setups" do
    result = described_class.call(bars: bars([ 100.0, 101.0 ]), sma_50: nil, pivot: 100.0, breakout: false)

    expect(result).to include(adr_pct: nil, extension_adr: nil, day_move_adr: nil, breakout_age: nil, flags: [])
    expect(described_class.call(bars: [], sma_50: 100.0)).to eq({})
  end
end
