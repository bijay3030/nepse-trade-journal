require "rails_helper"

RSpec.describe Setups::Patterns do
  def candle(close, high: close + 1, low: close - 1, open: close, volume: 1000, sma_20: nil, sma_50: nil, sma_200: nil)
    { traded_on: nil, open: open, high: high, low: low, close: close, volume: volume, sma_20: sma_20, sma_50: sma_50, sma_200: sma_200 }
  end

  describe ".ma_pullback" do
    # A steady uptrend: 50-day rising and above the 200-day; price back near the rising 20-day.
    def uptrend(last_close:, last_volume: 500)
      Array.new(60) { |i| candle(100.0 + i, sma_20: 90.0 + i, sma_50: 80.0 + i, sma_200: 60.0 + i * 0.5) } +
        [ candle(last_close, volume: last_volume, sma_20: 150.0, sma_50: 140.0, sma_200: 90.0) ]
    end

    it "anchors the zone on a rising 20-day average near the price" do
      result = described_class.ma_pullback(uptrend(last_close: 152.0))

      expect(result).to include(success: true, zone_low: 150.0, pivot: nil, quality: 100)
      expect(result[:zone_high]).to be_within(0.001).of(153.0)
      expect(result[:invalidation]).to be_within(0.001).of(144.0)
      expect(result[:details]).to include(anchor: "20-day", pulled_back: true, volume_quiet: true)
    end

    it "uses the 50-day when the price has slipped under the 20-day" do
      result = described_class.ma_pullback(uptrend(last_close: 141.0))

      expect(result).to include(success: true, zone_low: 140.0)
      expect(result[:details][:anchor]).to eq("50-day")
    end

    it "rejects a stock below a falling 50-day average" do
      falling = Array.new(61) { |i| candle(200.0 - i, sma_20: 205.0 - i, sma_50: 210.0 - i, sma_200: 220.0) }

      expect(described_class.ma_pullback(falling)).to eq(success: false, error: "Not an uptrend above a rising 50-day average")
    end
  end

  describe ".base_breakout" do
    def with_base(depth_pct:, near_high: true, quiet: true)
      run_up = Array.new(40) { |i| candle(60.0 + i, high: 61.0 + i, volume: 3000) } # peaks at 100
      top = near_high ? 100.0 : 90.0
      bottom = top * (1 - depth_pct / 100.0)
      base = Array.new(30) do |i|
        volume = quiet && i >= 15 ? 800 : 2000
        candle((top + bottom) / 2, high: i.even? ? top : top - 1, low: i.odd? ? bottom : bottom + 1, volume: volume)
      end
      run_up + base + [ candle(top + 1, high: top + 2, low: top - 1, volume: 5000) ]
    end

    it "finds a tight base at the 52-week high with the pivot at its top" do
      result = described_class.base_breakout(with_base(depth_pct: 8))

      expect(result).to include(success: true, zone_low: 100.0, pivot: 100.0, invalidation: 92.0, quality: 100)
      expect(result[:zone_high]).to be_within(0.001).of(103.0)
      # The run-up's peak bar plus the 30 sideways sessions.
      expect(result[:details]).to include(base_sessions: 31, base_depth_pct: 8.0, high_52w: 100.0, volume_drying_up: true)
    end

    it "caps the risk at 8% below the pivot for a deeper base" do
      result = described_class.base_breakout(with_base(depth_pct: 14))

      expect(result[:invalidation]).to be_within(0.001).of(92.0)
      expect(result[:quality]).to eq(25 + 20 + 20 + 20)
    end

    it "rejects a base far below the 52-week high and a base that is too deep" do
      expect(described_class.base_breakout(with_base(depth_pct: 8, near_high: false))[:error]).to eq("Base high is more than 5% below the 52-week high")
      expect(described_class.base_breakout(with_base(depth_pct: 25))[:error]).to eq("No flat base (15-60 sessions, at most 15% deep)")
    end
  end

  describe ".bullish_candle_at?" do
    it "needs an up-close in the upper half of the range with the low near support" do
      expect(described_class.bullish_candle_at?(candle(104, open: 100, high: 105, low: 99.5), 100)).to be(true)
      expect(described_class.bullish_candle_at?(candle(100, open: 104, high: 105, low: 99.5), 100)).to be(false) # down close
      expect(described_class.bullish_candle_at?(candle(104, open: 100, high: 105, low: 103), 100)).to be(false) # low not near support
    end
  end

  # Trading days (Sunday-Thursday) from Sunday 2026-06-07.
  def sessions(count) = (0..).lazy.map { Date.new(2026, 6, 7) + _1 }.reject { _1.friday? || _1.saturday? }.first(count)

  def dated(closes, sma_50: ->(i) { 80.0 + i * 0.5 }, sma_200: nil, volume: 1000, lows: {})
    sessions(closes.size).each_with_index.map do |date, i|
      close = closes[i]
      candle(close, low: lows.fetch(i, close - 1), volume: volume.is_a?(Proc) ? volume.(i) : volume, sma_50: sma_50.(i), sma_200: sma_200)
        .merge(traded_on: date.iso8601)
    end
  end

  describe ".three_weeks_tight" do
    # 45 sessions rising from 100 to 144, then three weeks closing at 150, 151 and 150.5.
    let(:rise) { Array.new(45) { 100.0 + _1 } }

    it "finds three weekly closes within 1.5% above a rising 50-day, with the pattern high as pivot" do
      tight = [ 148.0, 149.0, 150.5, 149.5, 150.0 ] + [ 150.5, 151.5, 150.0, 151.0, 151.0 ] + [ 150.0, 150.8, 151.2, 150.4, 150.5 ]
      result = described_class.three_weeks_tight(dated(rise + tight, volume: ->(i) { i < 45 ? 1000 : 600 }))

      expect(result).to include(success: true, zone_low: 152.5, invalidation: 147.0, pivot: 152.5)
      expect(result[:zone_high]).to be_within(0.01).of(157.08)
      expect(result[:details]).to include(weekly_closes: [ 150.0, 151.0, 150.5 ], spread_pct: 0.67, volume_quiet: true)
      expect(result[:quality]).to eq(80)
    end

    it "rejects loose weekly closes or a stock under its 50-day" do
      loose = [ 148.0 ] * 5 + [ 152.0 ] * 5 + [ 156.0 ] * 5

      expect(described_class.three_weeks_tight(dated(rise + loose))[:error]).to eq("Weekly closes aren't within 1.5% of each other")
      expect(described_class.three_weeks_tight(dated(rise + [ 150.0 ] * 15, sma_50: ->(_) { 160.0 }))[:success]).to be(false)
    end
  end

  describe ".undercut_rally" do
    # 30 sessions holding above a 100 low, a dip to 97 three sessions ago, then a close back at 101.
    def shakeout(last_close: 101.0, dip: 97.0)
      closes = Array.new(30) { 105.0 + (_1 % 3) } + [ 103.0, 99.0, dip + 1, 100.5, last_close ]
      lows = { 10 => 100.0, 32 => dip }
      dated(closes, sma_200: 90.0, lows: lows, volume: ->(i) { i == 33 ? 2000 : 1000 })
    end

    it "finds a dip under a prior low that closes back above it" do
      result = described_class.undercut_rally(shakeout)

      expect(result).to include(success: true, zone_low: 100.0, zone_high: 103.0, pivot: nil, invalidation: 96.03)
      expect(result[:details]).to include(prior_low: 100.0, undercut_low: 97.0, undercut_pct: 3.0, reclaimed_on_volume: true)
    end

    it "needs the close back above the prior low, and a shallow undercut" do
      expect(described_class.undercut_rally(shakeout(last_close: 99.5))[:error]).to eq("Not back above the prior low")
      expect(described_class.undercut_rally(shakeout(dip: 90.0))[:error]).to match(/more than 8.0% below/)
    end
  end
end
