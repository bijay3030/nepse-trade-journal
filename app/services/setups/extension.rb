module Setups
  # How stretched a stock is, measured in its own average daily range (ADR), plus how
  # fresh a breakout is. Point in time: only bars up to the session are used.
  #
  #   adr_pct        average of (high / low - 1) over the last 20 sessions, in %
  #   extension_adr  distance above the 50-day average in ADRs; EXTENDED_ADR or more
  #                  is "extended" (Minervini/Deepvue-style: a pullback is likely)
  #   day_move_adr   the session's change in ADRs; more than BIG_MOVE_ADR means the
  #                  day already ran further than usual (don't chase it)
  #   breakout_age   for breakout setups: sessions since price first closed above the
  #                  pivot in the current run (0 = today); STALE_SESSIONS or more is stale
  #
  # Flags are information; whether any of them keeps a stock off the board is decided
  # by the backtest (Backtest::Runner groups :extension, :day_move, :breakout_age).
  module Extension
    ADR_SESSIONS = 20
    EXTENDED_ADR = 4.0
    BIG_MOVE_ADR = 1.0
    STALE_SESSIONS = 5
    FLAGS = %w[extended big_move stale_breakout].freeze

    module_function

    # bars: price rows (high_price, low_price, close_price) oldest first, ending at the session.
    def call(bars:, sma_50:, pivot: nil, breakout: false, change_pct: nil)
      return {} if bars.empty?

      close = bars.last.close_price.to_f
      adr = adr_pct(bars)
      change = change_pct || day_change(bars)
      result = {
        adr_pct: adr&.round(2),
        extension_adr: adr && sma_50.to_f.positive? ? (((close / sma_50.to_f) - 1) * 100 / adr).round(2) : nil,
        day_move_adr: adr && change ? (change / adr).round(2) : nil,
        breakout_age: breakout && pivot.to_f.positive? ? breakout_age(bars, pivot.to_f) : nil
      }
      result.merge(flags: flags(result))
    end

    def adr_pct(bars)
      recent = bars.last(ADR_SESSIONS).select { _1.low_price.to_f.positive? }
      return if recent.size < 5

      (recent.sum { (_1.high_price.to_f / _1.low_price.to_f - 1) * 100 } / recent.size).then { _1.positive? ? _1 : nil }
    end

    def day_change(bars)
      return if bars.size < 2

      previous = bars[-2].close_price.to_f
      previous.positive? ? (bars.last.close_price.to_f / previous - 1) * 100 : nil
    end

    # Consecutive closes above the pivot ending at the session, minus one; nil when
    # the session didn't close above it.
    def breakout_age(bars, pivot)
      run = bars.reverse.take_while { _1.close_price.to_f > pivot }.size
      run.zero? ? nil : run - 1
    end

    def flags(result)
      flags = []
      flags << "extended" if result[:extension_adr] && result[:extension_adr] >= EXTENDED_ADR
      flags << "big_move" if result[:day_move_adr] && result[:day_move_adr] > BIG_MOVE_ADR
      flags << "stale_breakout" if result[:breakout_age] && result[:breakout_age] >= STALE_SESSIONS
      flags
    end
  end
end
