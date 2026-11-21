require "rails_helper"

RSpec.describe Lab::Strategies do
  def series(closes, opens: nil, highs: nil, lows: nil)
    {
      dates: closes.each_index.map { Date.new(2025, 1, 1) + _1 }, close: closes.map(&:to_f),
      open: (opens || closes).map(&:to_f), high: (highs || closes.map { _1 * 1.01 }).map(&:to_f), low: (lows || closes.map { _1 * 0.99 }).map(&:to_f),
      rsi: described_class.rsi(closes.map(&:to_f), 14), sma50: described_class.sma(closes.map(&:to_f), 50), sma200: described_class.sma(closes.map(&:to_f), 200)
    }
  end

  it "computes Wilder's RSI and simple averages" do
    expect(described_class.rsi([ 1.0 ] + (1..20).map { 1.0 + _1 }, 14).last).to eq(100.0)
    rsi = described_class.rsi((0..40).map { 100 + (_1.even? ? 1.0 : -1.0) }, 14).last
    expect(rsi).to be_between(45, 55)
    expect(described_class.sma([ 1, 2, 3, 4 ].map(&:to_f), 2)).to eq([ nil, 1.5, 2.5, 3.5 ])
  end

  it "triggers the RSI reversion when an oversold uptrend stock turns up" do
    closes = (0...230).map { 100 + _1 * 0.5 } + [ 205, 200, 195, 190, 186, 183, 185.5 ] # sharp pullback, then an up day
    s = series(closes)
    i = closes.size - 1
    expect(s[:rsi][i - 1]).to be < 30
    levels = described_class.trigger(s, "rsi_reversion", i)
    expect(levels).to include(entry_low: 185.5, entry_high: 189.21)
    expect(levels[:stop]).to be < 185.5
    expect(levels[:target]).to eq((185.5 + 2 * (185.5 - levels[:stop])).round(2))
    expect(described_class.trigger(s, "rsi_reversion", i - 1)).to be_nil # still falling
  end

  it "triggers the range bounce near the bottom of a flat range" do
    closes = (0...150).map { |i| 100 + 8 * Math.sin(i / 6.0) } # a 92-108 range
    i = (70...150).find { |k| closes[k] < 93 && closes[k] > closes[k - 1] }
    opens = closes.dup
    opens[i] = closes[i] - 0.5
    s = series(closes, opens: opens)
    levels = described_class.trigger(s, "range_grid", i)
    expect(levels).to include(:range_low, :range_high)
    expect(levels[:target]).to be > 100
    expect(levels[:stop]).to be < levels[:range_low]
  end

  describe ".simulate" do
    let(:levels) { { entry_low: 100.0, entry_high: 102.0, stop: 95.0, target: 110.0 } }

    def run(opens:, highs:, lows:, closes:, key: "range_grid")
      s = { dates: closes.each_index.map { Date.new(2025, 1, 1) + _1 }, open: opens, high: highs, low: lows, close: closes, rsi: Array.new(closes.size) }
      described_class.simulate(s, key, 0, levels)
    end

    it "fills at the next open, exits at the target net of costs" do
      trade = run(opens: [ 100, 101, 104 ], highs: [ 101, 105, 111 ], lows: [ 99, 100, 103 ], closes: [ 100, 104, 109 ])
      expect(trade).to include(status: :closed, entry: 101.0, exit: 110.0, reason: "target", return_pct: (9 / 101.0 * 100 - 0.8).round(2))
    end

    it "skips a gap above the entry range and reports pending/open trades" do
      expect(run(opens: [ 100, 104 ], highs: [ 101, 105 ], lows: [ 99, 103 ], closes: [ 100, 104 ])).to include(status: :skipped)
      expect(run(opens: [ 100 ], highs: [ 101 ], lows: [ 99 ], closes: [ 100 ])).to eq(status: :pending)
      expect(run(opens: [ 100, 101 ], highs: [ 101, 103 ], lows: [ 99, 100 ], closes: [ 100, 102 ])).to include(status: :open, exit: 102.0)
    end

    it "exits the RSI strategy at the close once RSI reaches the exit level" do
      s = { dates: (0..2).map { Date.new(2025, 1, 1) + _1 }, open: [ 100, 101, 103 ], high: [ 101, 104, 105 ], low: [ 99, 100, 102 ],
            close: [ 100, 103, 104 ], rsi: [ 25, 50, 66 ] }
      expect(described_class.simulate(s, "rsi_reversion", 0, levels)).to include(status: :closed, reason: "rsi_exit", exit: 104.0)
    end
  end
end
