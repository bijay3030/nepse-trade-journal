module Indicators
  # Trend indicators as full series aligned with the input (nil until there's enough
  # history), with TradingView's formulas so values match its charts:
  #
  #   ema(n)    exponential average, k = 2 / (n + 1), seeded with the simple average
  #   wma(n)    linearly weighted average (newest weight n)
  #   hma(n)    Hull: WMA(2 * WMA(n/2) - WMA(n), floor(sqrt(n))), little lag
  #   alma(n, offset, sigma)  Arnaud Legoux: Gaussian weights centred at offset * (n - 1)
  #   aroon(n)  Up/Down = 100 * (n - bars since the highest high / lowest low) / n over
  #             the last n + 1 bars
  module Trend
    module_function

    def ema(values, n)
      out = Array.new(values.size)
      return out if values.size < n

      k = 2.0 / (n + 1)
      out[n - 1] = values.first(n).sum / n.to_f
      (n...values.size).each { |i| out[i] = values[i] * k + out[i - 1] * (1 - k) }
      out
    end

    def wma(values, n)
      denominator = n * (n + 1) / 2.0
      values.each_index.map do |i|
        next if i < n - 1 || values[(i - n + 1)..i].any?(&:nil?)

        values[(i - n + 1)..i].each_with_index.sum { |value, j| value * (j + 1) } / denominator
      end
    end

    def hma(values, n)
      half = wma(values, n / 2)
      full = wma(values, n)
      raw = half.zip(full).map { |h, f| h && f ? 2 * h - f : nil }
      wma(raw, Math.sqrt(n).floor)
    end

    def alma(values, n, offset: 0.85, sigma: 6.0)
      m = offset * (n - 1)
      s = n / sigma
      weights = Array.new(n) { |i| Math.exp(-((i - m)**2) / (2 * s * s)) }
      total = weights.sum
      values.each_index.map do |i|
        next if i < n - 1

        values[(i - n + 1)..i].each_with_index.sum { |value, j| value * weights[j] } / total
      end
    end

    # { up: [...], down: [...] }
    def aroon(highs, lows, n)
      up = Array.new(highs.size)
      down = Array.new(lows.size)
      (n...highs.size).each do |i|
        window = (i - n)..i
        high_at = window.max_by { |j| [ highs[j], j ] }
        low_at = window.min_by { |j| [ lows[j], -j ] }
        up[i] = 100.0 * (n - (i - high_at)) / n
        down[i] = 100.0 * (n - (i - low_at)) / n
      end
      { up: up, down: down }
    end
  end
end
