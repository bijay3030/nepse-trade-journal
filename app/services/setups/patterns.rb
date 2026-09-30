module Setups
  # Setup patterns beyond VCP, detected from Stock::SetupAnalysis candles
  # (open/high/low/close/volume with 20/50/200-day averages). Each returns the
  # zone core (zone low / high, invalidation, pivot), a 0-100 quality and details,
  # or a reason when the stock doesn't fit.
  module Patterns
    # Pullback to a rising average: an uptrend (close above a rising 50-day, 50 above
    # 200 when known) pulling back to its rising 20-day average, or to the 50-day
    # when it has slipped under the 20. Zone: the average to 2% above it; the setup
    # fails 4% below the average.
    MA_ZONE_PCT = 2.0
    MA_BREAK_PCT = 4.0
    MA_NEAR_PCT = 3.0
    MA_SLOPE_SESSIONS = 10

    # Flat-base breakout: the longest recent base (15-60 sessions) whose range is at
    # most 15% deep, with its high within 5% of the 52-week high. Pivot: the base
    # high; zone: pivot to 3% above; fails at the base low, or 8% below the pivot if
    # the base is deeper than that.
    BASE_MIN = 15
    BASE_MAX = 60
    BASE_MAX_DEPTH_PCT = 15.0
    BASE_NEAR_HIGH_PCT = 5.0
    BASE_ZONE_PCT = 3.0
    BASE_MAX_RISK_PCT = 8.0

    module_function

    def ma_pullback(candles)
      last = candles.last
      return fail_with("Not enough history for the 50-day average") unless last && last[:sma_50]

      sma50_then = candles[-1 - MA_SLOPE_SESSIONS]&.dig(:sma_50)
      rising50 = sma50_then && last[:sma_50] > sma50_then
      above200 = last[:sma_200].nil? || last[:sma_50] > last[:sma_200]
      unless last[:close] > last[:sma_50] * (1 - MA_NEAR_PCT / 100) && rising50 && above200
        return fail_with("Not an uptrend above a rising 50-day average")
      end

      sma20_then = candles[-6]&.dig(:sma_20)
      use20 = last[:sma_20] && sma20_then && last[:sma_20] > sma20_then && last[:close] >= last[:sma_20] * (1 - MA_NEAR_PCT / 100)
      anchor, name = use20 ? [ last[:sma_20], "20-day" ] : [ last[:sma_50], "50-day" ]

      near = last[:close] <= anchor * (1 + MA_NEAR_PCT / 100)
      quiet = average(candles.last(5).map { _1[:volume].to_f }) < average(candles.last(50).map { _1[:volume].to_f })
      quality = 40 + (last[:sma_200] && last[:sma_50] > last[:sma_200] ? 20 : 0) + (near ? 20 : 0) + (quiet ? 20 : 0)

      success(
        zone_low: anchor, zone_high: anchor * (1 + MA_ZONE_PCT / 100), invalidation: anchor * (1 - MA_BREAK_PCT / 100), pivot: nil,
        quality: quality,
        details: { anchor: name, anchor_value: anchor.round(2), pulled_back: near, volume_quiet: quiet }
      )
    end

    def base_breakout(candles)
      return fail_with("Not enough history for a base") if candles.size < BASE_MIN + 1

      # The latest bar may be the breakout itself, so the base and the 52-week high
      # it is compared with come from the bars before it.
      prior = candles[0...-1]
      high52 = prior.last(250).map { _1[:high] }.max
      base = BASE_MAX.downto(BASE_MIN).lazy.filter_map do |length|
        next if prior.size < length

        window = prior.last(length)
        # A base moves sideways from a peak: start it at the window's highest bar so
        # the tail of the prior advance isn't counted as part of the base.
        window = window.drop(window.index { _1[:high] == window.map { |c| c[:high] }.max })
        next if window.size < BASE_MIN

        top = window.map { _1[:high] }.max
        bottom = window.map { _1[:low] }.min
        depth = (top - bottom) / top * 100
        { length: window.size, top: top, bottom: bottom, depth: depth, window: window } if depth <= BASE_MAX_DEPTH_PCT
      end.first
      return fail_with("No flat base (15-60 sessions, at most 15% deep)") unless base
      return fail_with("Base high is more than 5% below the 52-week high") if base[:top] < high52 * (1 - BASE_NEAR_HIGH_PCT / 100)

      pivot = base[:top]
      invalidation = [ base[:bottom], pivot * (1 - BASE_MAX_RISK_PCT / 100) ].max
      half = base[:window].size / 2
      quiet = average(base[:window].last(half).map { _1[:volume].to_f }) < average(base[:window].first(half).map { _1[:volume].to_f })
      quality = (base[:depth] <= 10 ? 40 : 25) + (quiet ? 20 : 0) + (pivot >= high52 * 0.999 ? 20 : 0) + (base[:length] >= 25 ? 20 : 0)

      success(
        zone_low: pivot, zone_high: pivot * (1 + BASE_ZONE_PCT / 100), invalidation: invalidation, pivot: pivot,
        quality: quality,
        details: { base_sessions: base[:length], base_depth_pct: base[:depth].round(2), base_low: base[:bottom].round(2),
                   high_52w: high52.round(2), volume_drying_up: quiet }
      )
    end

    # A bullish candle at support: closes up, in the upper half of its range, with
    # its low within 2% of the support level.
    def bullish_candle_at?(candle, support)
      return false unless candle && support.to_f.positive?

      range = candle[:high] - candle[:low]
      candle[:close] > candle[:open] && range.positive? && (candle[:close] - candle[:low]) / range >= 0.5 &&
        candle[:low] <= support * 1.02
    end

    def success(**fields) = { success: true, **fields }
    def fail_with(reason) = { success: false, error: reason }

    def average(values)
      values = values.compact
      values.empty? ? 0.0 : values.sum / values.size
    end
  end
end
