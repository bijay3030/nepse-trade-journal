require "rails_helper"

RSpec.describe Scans::Levels do
  # 30 bars with a 2% daily range (high 101, low 99); EMA 21 given per case.
  def series(close: 100.0, ema21: 95.0)
    n = 30
    { close: Array.new(n, close), high: Array.new(n) { close * 1.01 }, low: Array.new(n) { close * 0.99 }, ema21: Array.new(n, ema21) }
  end

  it "sets entry to 1 ADR above the close, the stop just under EMA 21 and the target at 2R" do
    levels = described_class.crossover(series, 29)

    expect(levels).to include(entry_low: 100.0, entry_high: 102.02, stop: 94.05, target: 111.9, source: "crossover")
  end

  it "uses 2 ADR below the entry when EMA 21 is above the price, and caps the stop at 8%" do
    expect(described_class.crossover(series(ema21: 105.0), 29)[:stop]).to eq(95.96)
    expect(described_class.crossover(series(ema21: 50.0), 29)[:stop]).to eq(92.0)
    expect(described_class.crossover(series, 5)).to be_nil # not enough bars for ADR
  end

  it "prefers a live board setup's levels" do
    snapshot = { setup_type: "vcp", zone_state: "too_early", entry_zone_low: 550, entry_zone_high: 566.5, invalidation_price: 512, target_price: 617 }

    expect(described_class.board(snapshot)).to eq(entry_low: 550.0, entry_high: 566.5, stop: 512.0, target: 617.0, source: "board_setup", setup_type: "vcp")
    expect(described_class.board(snapshot.merge(zone_state: "failed"))).to be_nil
    expect(described_class.board(nil)).to be_nil
  end
end

RSpec.describe Scans::CrossoverBacktest, ".simulate" do
  def bars(closes, opens: closes, highs: closes.map { _1 * 1.01 }, lows: closes.map { _1 * 0.99 })
    { close: closes, open: opens, high: highs, low: lows, ema21: Array.new(closes.size, closes.first * 0.95) }
  end

  it "buys the next open inside the zone and exits at the target or the stop, net of costs" do
    closes = Array.new(25, 100.0) + [ 101.0, 104.0, 108.0, 113.0 ]
    up = described_class.simulate(bars(closes, highs: closes.map { _1 + 1 }, lows: closes.map { _1 - 1 }), 24)
    expect(up).to include(status: :closed, reason: "target")
    expect(up[:r]).to be > 1.5

    down = Array.new(25, 100.0) + [ 99.0, 96.0, 93.0 ]
    expect(described_class.simulate(bars(down, highs: down.map { _1 + 1 }, lows: down.map { _1 - 1 }), 24)).to include(status: :closed, reason: "stop")
  end

  it "skips a next-day gap above the entry zone" do
    closes = Array.new(25, 100.0) + [ 110.0 ]
    expect(described_class.simulate(bars(closes, opens: Array.new(25, 100.0) + [ 109.0 ]), 24)).to eq(status: :skipped)
  end
end
