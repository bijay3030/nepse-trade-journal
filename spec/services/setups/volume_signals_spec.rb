require "rails_helper"

RSpec.describe Setups::VolumeSignals do
  Day = Struct.new(:close_price, :volume)

  # 60 sessions alternating up and down closes around 100 on 1,000 shares, then the given days.
  def bars(tail = [], up_volume: 1_000, down_volume: 1_000)
    base = Array.new(60) { |i| i.even? ? Day.new(100.0, down_volume) : Day.new(101.0, up_volume) }
    base + tail.map { Day.new(*_1) }
  end

  it "measures the 50-session up/down volume ratio" do
    expect(described_class.call(bars: bars(up_volume: 1_500))[:up_down_ratio]).to eq(1.5)
    expect(described_class.call(bars: bars(up_volume: 1_500))[:flags]).to include("strong_up_down")
    expect(described_class.call(bars: bars(down_volume: 1_500))[:flags]).to include("weak_up_down")
  end

  it "finds a pocket pivot: an up close above every recent down day's volume, near the 10-day average" do
    signals = described_class.call(bars: bars([ [ 102.0, 1_200 ] ]))
    expect(signals).to include(pocket_pivot_age: 0)
    expect(signals[:flags]).to include("pocket_pivot")

    expect(described_class.call(bars: bars([ [ 102.0, 1_200 ], [ 101.5, 500 ], [ 101.8, 600 ] ]))[:pocket_pivot_age]).to eq(2)
    expect(described_class.call(bars: bars([ [ 102.0, 900 ] ]))[:pocket_pivot_age]).to be_nil   # not more than the down days
    expect(described_class.call(bars: bars([ [ 112.0, 5_000 ] ]))[:pocket_pivot_age]).to be_nil # too far above the 10-day
  end

  it "counts dry-up days: sessions on under half the 50-day average volume" do
    signals = described_class.call(bars: bars([ [ 100.5, 300 ], [ 100.4, 400 ], [ 100.6, 900 ], [ 100.7, 1_000 ] ]))

    expect(signals[:dry_up_days]).to eq(2)
    expect(signals[:flags]).to include("dry_up")
  end

  it "skips thinly traded stocks" do
    expect(described_class.call(bars: Array.new(60) { |i| Day.new(100.0 + i % 2, i < 30 ? 0 : 1_000) })).to eq({})
  end
end

RSpec.describe Setups::BaseCount do
  def leg(from, to, sessions) = Array.new(sessions) { |k| from + (to - from) * (k + 1) / sessions.to_f }

  let(:three_bases) do
    leg(130, 100, 30) + leg(100, 150, 20) + leg(150, 130, 10) + leg(130, 150, 10) + [ 155 ] +
      leg(155, 175, 10) + leg(175, 150, 10) + leg(150, 175, 8) + [ 180 ] + leg(180, 195, 5) + leg(195, 170, 12)
  end

  it "counts bases from the low: two breakouts and a third base in progress is late stage" do
    expect(described_class.call(three_bases)).to eq(base_number: 3, in_base: true, partial: false, depth_pct: 12.8, flags: [ "late_stage_base" ])
  end

  it "reports the base just broken out of, and nothing before the first base" do
    expect(described_class.call(three_bases.first(72))).to include(base_number: 1, in_base: false)
    expect(described_class.call(leg(100, 150, 40))).to include(base_number: nil)
  end

  it "ignores dips shorter or shallower than a base" do
    shallow = leg(130, 100, 30) + leg(100, 150, 20) + leg(150, 140, 10) + leg(140, 160, 10)
    quick = leg(130, 100, 30) + leg(100, 150, 20) + leg(150, 130, 4) + leg(130, 160, 4)

    expect(described_class.call(shallow)[:base_number]).to be_nil
    expect(described_class.call(quick)[:base_number]).to be_nil
  end

  it "resets the count when a base undercuts the previous base's low" do
    closes = leg(130, 100, 30) + leg(100, 150, 20) + leg(150, 130, 10) + leg(130, 155, 10) + leg(155, 125, 15)

    expect(described_class.call(closes)).to include(base_number: 1, in_base: true)
  end

  it "marks the count partial when the low is at the start of the history" do
    expect(described_class.call(leg(100, 150, 20) + leg(150, 130, 10) + leg(130, 155, 10))).to include(base_number: 1, partial: true)
  end
end
