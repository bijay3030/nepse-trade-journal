module Setups
  # Which base the stock is in, counted from its lowest close in the price history
  # (IBD: 1st and 2nd-stage bases work best; 3rd+ fail more often, ~80% of 4th-stage ones).
  #
  # From the low, a base starts when the price falls MIN_DEPTH_PCT from a high and ends
  # when it closes above that high again (a breakout) after at least MIN_SESSIONS. A base
  # whose low undercuts the previous base's low resets the count. base_number is the
  # current base (in progress) or, after a breakout, the base just broken out of.
  #
  # Price history is about a year, so when the low is within EARLY_SESSIONS of the first
  # bar, earlier bases may be missing: `partial` is true and the count reads "N+".
  module BaseCount
    MIN_DEPTH_PCT = 10.0
    MIN_SESSIONS = 15
    EARLY_SESSIONS = 20
    LATE_STAGE = 3

    module_function

    # closes: oldest first, ending at the session.
    def call(closes)
      closes = closes.map(&:to_f)
      return {} if closes.size < MIN_SESSIONS * 2

      low_at = closes.each_with_index.min_by(&:first).last
      completed = 0
      high = high_at = nil
      base = nil # { high:, started:, low: }
      previous_low = nil

      closes[low_at..].each_with_index do |close, offset|
        i = low_at + offset
        if base
          base[:low] = [ base[:low], close ].min
          next unless close > base[:high]

          if i - base[:started] >= MIN_SESSIONS
            completed = previous_low && base[:low] < previous_low ? 1 : completed + 1
            previous_low = base[:low]
          end
          base = nil
          high, high_at = close, i
        elsif high.nil? || close >= high
          high, high_at = close, i
        elsif close <= high * (1 - MIN_DEPTH_PCT / 100)
          base = { high: high, started: high_at, low: close }
        end
      end

      in_base = !base.nil?
      reset = in_base && previous_low && base[:low] < previous_low
      number = if reset then 1
      elsif in_base then completed + 1
      else completed
      end
      return { base_number: nil, in_base: false, partial: false, flags: [] } if number.zero?

      partial = low_at < EARLY_SESSIONS
      {
        base_number: number, in_base: in_base, partial: partial,
        depth_pct: in_base ? ((1 - base[:low] / base[:high]) * 100).round(1) : nil,
        flags: number >= LATE_STAGE ? [ "late_stage_base" ] : []
      }
    end
  end
end
