module Setups
  # IBD-style relative strength: a weighted 12-month performance score, ranked
  # against every stock analysed into a 1-99 rating (99 = strongest).
  #
  # score = 0.4 * C/C63 + 0.2 * C/C126 + 0.2 * C/C189 + 0.2 * C/C252
  # (C = latest close, Cn = close n sessions ago). The most recent quarter counts
  # double. With less history, the oldest available close stands in for the missing ones.
  module RelativeStrength
    PERIODS = { 63 => 0.4, 126 => 0.2, 189 => 0.2, 252 => 0.2 }.freeze
    MIN_SESSIONS = 63

    module_function

    def score(closes)
      closes = closes.map(&:to_f).select(&:positive?)
      return if closes.size <= MIN_SESSIONS

      latest = closes.last
      PERIODS.sum { |sessions, weight| weight * latest / closes[[ closes.size - 1 - sessions, 0 ].max] }.round(4)
    end

    # { key => score } => { key => 1..99 }
    def ratings(scores)
      ranked = scores.compact.sort_by { |_key, value| value }
      return {} if ranked.empty?

      ranked.each_with_index.to_h do |(key, _value), index|
        percentile = ranked.size == 1 ? 99 : 1 + ((index.to_f / (ranked.size - 1)) * 98).round
        [ key, percentile ]
      end
    end
  end
end
