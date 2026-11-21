module Lab
  # Two strategies adapted from opentrader (github.com/Open-Trader/opentrader, a crypto
  # bot) for NEPSE's daily, long-only market: its RSI strategy as a mean reversion in an
  # uptrend, and its GRID strategy as one trade per bounce off the bottom of a sideways
  # range (NEPSE can't be shorted and a ladder of orders isn't practical on daily bars).
  #
  #   rsi_reversion  the close is above its 200-day average, RSI(14) was under OVERSOLD
  #                  within the last OVERSOLD_WITHIN sessions and turned up today on a
  #                  higher close. Stop just under the 5-session low (at most MAX_STOP_PCT
  #                  away), target 2x the risk; also exits at the close once RSI reaches
  #                  RSI_EXIT.
  #   range_grid     the last RANGE sessions moved within RANGE_MIN_PCT..RANGE_MAX_PCT of
  #                  their low and the 50-day average is flat (within FLAT_PCT over 20
  #                  sessions); today closes in the bottom BOTTOM_SHARE of that range,
  #                  above its open and the previous close. Stop 3% under the range low (at
  #                  most MAX_STOP_PCT away), target near the top of the range.
  #
  # Trades follow the board backtest's terms: buy at the next open if it's inside the
  # entry range (a gap above is chasing, a gap to the stop is a failed setup), exit at
  # the stop or target (a gap through either exits at that open; both on one day count
  # as the stop), on the strategy's own exit, or at the close after HOLD sessions.
  # Returns are net of COST_PCT round trip. Rule checks, not advice.
  module Strategies
    KEYS = %w[rsi_reversion range_grid].freeze
    LABELS = { "rsi_reversion" => "RSI mean reversion", "range_grid" => "Range (grid) bounce" }.freeze
    RSI_PERIOD = 14
    OVERSOLD = 30
    OVERSOLD_WITHIN = 3
    RSI_EXIT = 65
    RANGE = 60
    RANGE_MIN_PCT = 8.0
    RANGE_MAX_PCT = 30.0
    FLAT_PCT = 3.0
    BOTTOM_SHARE = 0.2
    MAX_STOP_PCT = 8.0
    ENTRY_SPAN_PCT = 2.0
    REWARD_MULTIPLE = 2.0
    HOLD = { "rsi_reversion" => 20, "range_grid" => 30 }.freeze
    COST_PCT = ::Backtest::Runner::ROUND_TRIP_COST_PCT
    MIN_RISK_PCT = ::Backtest::Runner::MIN_RISK_PCT
    MIN_BARS = 220

    module_function

    # rows: [[date, high, low, close, open, volume], ...] oldest first (Scans::History).
    def prepare(rows)
      closes = rows.map { _1[3] }
      {
        dates: rows.map(&:first), close: closes,
        high: rows.map { [ _1[1], _1[3] ].max }, low: rows.map { _1[2].positive? ? [ _1[2], _1[3] ].min : _1[3] },
        open: rows.map { _1[4].positive? ? _1[4] : _1[3] },
        rsi: rsi(closes, RSI_PERIOD), sma50: sma(closes, 50), sma200: sma(closes, 200)
      }
    end

    # The levels when the strategy triggers on bar i, else nil.
    def trigger(s, key, i)
      key == "rsi_reversion" ? rsi_trigger(s, i) : range_trigger(s, i)
    end

    def rsi_trigger(s, i)
      return if i < OVERSOLD_WITHIN || s[:sma200][i].nil? || s[:rsi][i].nil?
      return unless s[:close][i] > s[:sma200][i] && s[:close][i] > s[:close][i - 1]

      recent = s[:rsi][(i - OVERSOLD_WITHIN)...i].compact
      return unless recent.any? && recent.min < OVERSOLD && s[:rsi][i] > s[:rsi][i - 1].to_f && s[:rsi][i] < RSI_EXIT

      close = s[:close][i]
      stop = [ s[:low][[ i - 4, 0 ].max..i].min * 0.99, close * (1 - MAX_STOP_PCT / 100) ].max
      levels(close, close * (1 + ENTRY_SPAN_PCT / 100), stop, close + REWARD_MULTIPLE * (close - stop))
    end

    def range_trigger(s, i)
      return if i < RANGE || s[:sma50][i].nil? || s[:sma50][i - 20].nil?

      high = s[:high][(i - RANGE)...i].max
      low = s[:low][(i - RANGE)...i].min
      return unless low.positive?

      width = (high / low - 1) * 100
      return unless width.between?(RANGE_MIN_PCT, RANGE_MAX_PCT)
      return unless ((s[:sma50][i] / s[:sma50][i - 20] - 1) * 100).abs <= FLAT_PCT

      close = s[:close][i]
      return unless close >= low && close <= low + BOTTOM_SHARE * (high - low)
      return unless close > s[:open][i] && close > s[:close][i - 1]

      stop = [ low * 0.97, close * (1 - MAX_STOP_PCT / 100) ].max
      entry_high = [ close * (1 + ENTRY_SPAN_PCT / 100), low + 0.25 * (high - low) ].min
      levels(close, [ entry_high, close ].max, stop, high - 0.1 * (high - low), range_low: low, range_high: high)
    end

    def levels(entry_low, entry_high, stop, target, **extra)
      return if target <= entry_high || stop >= entry_low

      { entry_low: entry_low.round(2), entry_high: entry_high.round(2), stop: stop.round(2), target: target.round(2),
        reward_risk: ((target - entry_low) / (entry_low - stop)).round(2), **extra.transform_values { _1.round(2) } }
    end

    # The trade from a trigger on bar i:
    #   { status: :pending }                     no session after the signal yet
    #   { status: :skipped, reason: }            the next open was outside the entry range
    #   { status: :open, ... }                   still held at the latest bar (marked to the close)
    #   { status: :closed, exit_index:, ... }    exited by a rule
    def simulate(s, key, i, levels)
      j = i + 1
      return { status: :pending } if j >= s[:close].size

      entry = s[:open][j]
      stop, target = levels[:stop], levels[:target]
      return { status: :skipped, reason: "gap above the entry range", entry_index: j } if entry > levels[:entry_high]
      return { status: :skipped, reason: "gap to the stop", entry_index: j } if entry <= stop
      return { status: :skipped, reason: "stop too close", entry_index: j } if (entry - stop) / entry * 100 < MIN_RISK_PCT

      last = [ j + HOLD[key] - 1, s[:close].size - 1 ].min
      (j..last).each do |k|
        price, reason =
          if s[:low][k] <= stop then [ k > j && s[:open][k] < stop ? s[:open][k] : stop, "stop" ]
          elsif s[:high][k] >= target then [ k > j && s[:open][k] > target ? s[:open][k] : target, "target" ]
          elsif key == "rsi_reversion" && s[:rsi][k] && s[:rsi][k] >= RSI_EXIT then [ s[:close][k], "rsi_exit" ]
          elsif k == j + HOLD[key] - 1 then [ s[:close][k], "time" ]
          end
        next unless price

        return trade(:closed, s, j, k, entry, price, stop, reason)
      end
      trade(:open, s, j, last, entry, s[:close][last], stop, nil)
    end

    def trade(status, s, j, k, entry, price, stop, reason)
      gross = (price / entry - 1) * 100
      {
        status: status, entry_index: j, exit_index: k, entry_on: s[:dates][j], exit_on: status == :closed ? s[:dates][k] : nil,
        entry: entry.round(2), exit: price.round(2), reason: reason,
        return_pct: (status == :closed ? gross - COST_PCT : gross).round(2), r: ((price - entry) / (entry - stop)).round(2)
      }
    end

    # Wilder's RSI.
    def rsi(closes, n)
      out = Array.new(closes.size)
      return out if closes.size <= n

      gain = loss = 0.0
      (1..n).each do |i|
        change = closes[i] - closes[i - 1]
        change.positive? ? gain += change : loss -= change
      end
      avg_gain, avg_loss = gain / n, loss / n
      out[n] = value(avg_gain, avg_loss)
      ((n + 1)...closes.size).each do |i|
        change = closes[i] - closes[i - 1]
        avg_gain = (avg_gain * (n - 1) + [ change, 0 ].max) / n
        avg_loss = (avg_loss * (n - 1) + [ -change, 0 ].max) / n
        out[i] = value(avg_gain, avg_loss)
      end
      out
    end

    def value(gain, loss) = loss.zero? ? 100.0 : (100 - 100 / (1 + gain / loss)).round(2)

    def sma(values, n)
      out = Array.new(values.size)
      sum = 0.0
      values.each_with_index do |v, i|
        sum += v
        sum -= values[i - n] if i >= n
        out[i] = (sum / n) if i >= n - 1
      end
      out
    end
  end
end
