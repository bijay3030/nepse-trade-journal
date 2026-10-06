module Setups
  module MovingAverage
    module_function

    # Exponential moving averages of `values` (oldest first), seeded with the simple
    # average of the first `period`; nil until there are enough values.
    def ema_series(values, period)
      values = values.map(&:to_f)
      return [] if values.size < period

      k = 2.0 / (period + 1)
      ema = values.first(period).sum / period
      [ ema ] + values.drop(period).map { ema = _1 * k + ema * (1 - k) }
    end
  end
end
