module Scans
  # How each Scans::Crossovers signal played out on our NEPSE history: every session
  # where a signal began (the cross, the turn, the stack forming) is a sample, and its
  # return over the next 5, 10 and 20 sessions (close to close, before costs) is
  # compared with NEPSE over the same sessions and with all stock-days (the baseline).
  # Indicators only use bars up to the signal day, so there's no look-ahead.
  module CrossoverBacktest
    HORIZONS = [ 5, 10, 20 ].freeze
    # Trades with Scans::Levels' crossover levels, on the board backtest's terms.
    MAX_HOLD = Backtest::Runner::MAX_HOLD
    COST_PCT = Backtest::Runner::ROUND_TRIP_COST_PCT
    MIN_RISK_PCT = Backtest::Runner::MIN_RISK_PCT

    module_function

    def call(now: Time.current)
      bars = Crossovers.load_bars(now)
      nepse = MarketIndexHistory.joins(:market_index).where(market_indices: { symbol: "NEPSE" }).pluck(:traded_on, :index_value).to_h { [ _1, _2.to_f ] }
      samples = Hash.new { |h, k| h[k] = [] }
      trades = Hash.new { |h, k| h[k] = [] }
      dates = []

      bars.each_value do |rows|
        next if rows.size < Crossovers::MIN_BARS

        series = Crossovers.compute(rows)
        closes = series[:close]
        dates.concat(series[:dates])
        forward = ->(i) { HORIZONS.to_h { |h| [ h, sample(series[:dates], closes, nepse, i, h) ] } }
        (0...closes.size).each { |i| samples["all"] << forward.(i) if closes[i].positive? }
        Crossovers::SIGNALS.each do |signal|
          busy_until = -1
          Crossovers.onsets(series, signal).each do |i|
            samples[signal] << forward.(i)
            next if i <= busy_until

            trade = simulate(series, i) or next
            trades[signal] << trade
            busy_until = trade[:exit_index] if trade[:status] == :closed
            busy_until = series[:close].size if trade[:status] == :open
          end
        end
      end

      {
        period: { from: dates.min, to: dates.max }, horizons: HORIZONS,
        signals: ([ "all" ] + Crossovers::SIGNALS).to_h { |key| [ key, HORIZONS.to_h { |h| [ h, stats(samples[key].filter_map { _1[h] }) ] } ] },
        trades: Crossovers::SIGNALS.to_h { |key| [ key, trade_stats(trades[key]) ] },
        trade_rules: { max_hold: MAX_HOLD, cost_pct: COST_PCT, reward_multiple: Levels::REWARD_MULTIPLE, max_stop_pct: Levels::MAX_STOP_PCT }
      }
    end

    # Buy at the next session's open if it's inside the entry zone (a gap above it is
    # skipped as chasing; a gap to or below the stop is skipped as failed); exit at the
    # stop or target (a gap through either exits at that open; both on one day count as
    # the stop) or at the close after MAX_HOLD sessions. Net of COST_PCT round trip.
    def simulate(series, i)
      levels = Levels.crossover(series, i) or return
      j = i + 1
      return if j >= series[:close].size

      entry = series[:open][j]
      stop, target = levels[:stop], levels[:target]
      return { status: :skipped } if entry > levels[:entry_high] || entry <= stop
      return { status: :skipped } if (entry - stop) / entry * 100 < MIN_RISK_PCT

      last = [ j + MAX_HOLD - 1, series[:close].size - 1 ].min
      (j..last).each do |k|
        price, reason =
          if series[:low][k] <= stop then [ k > j && series[:open][k] < stop ? series[:open][k] : stop, "stop" ]
          elsif series[:high][k] >= target then [ k > j && series[:open][k] > target ? series[:open][k] : target, "target" ]
          elsif k == j + MAX_HOLD - 1 then [ series[:close][k], "time" ]
          end
        next unless price

        return { status: :closed, exit_index: k, reason: reason, return_pct: (price / entry - 1) * 100 - COST_PCT, r: (price - entry) / (entry - stop) }
      end
      { status: :open }
    end

    def trade_stats(trades)
      closed = trades.select { _1[:status] == :closed }
      return { closed: 0, skipped: trades.count { _1[:status] == :skipped } } if closed.empty?

      returns = closed.map { _1[:return_pct] }
      wins = returns.select(&:positive?)
      losses = returns.reject(&:positive?)
      {
        closed: closed.size, skipped: trades.count { _1[:status] == :skipped },
        win_rate_pct: (wins.size * 100.0 / closed.size).round(1),
        avg_return_pct: (returns.sum / closed.size).round(2),
        avg_r: (closed.sum { _1[:r] } / closed.size).round(2),
        profit_factor: losses.sum.zero? ? nil : (wins.sum / -losses.sum).round(2),
        exits: closed.map { _1[:reason] }.tally
      }
    end

    # [return %, excess over NEPSE %] h sessions after bar i, or nil near the end.
    def sample(dates, closes, nepse, i, h)
      j = i + h
      return if j >= closes.size || !closes[i].positive?

      stock = (closes[j] / closes[i] - 1) * 100
      a, b = nepse[dates[i]], nepse[dates[j]]
      [ stock, a && b ? stock - (b / a - 1) * 100 : nil ]
    end

    def stats(values)
      return { n: 0 } if values.empty?

      returns = values.map(&:first).sort
      excess = values.filter_map(&:last)
      {
        n: values.size,
        avg_return_pct: (returns.sum / returns.size).round(2),
        median_return_pct: returns[returns.size / 2].round(2),
        win_rate_pct: (returns.count(&:positive?) * 100.0 / returns.size).round(1),
        avg_excess_pct: excess.empty? ? nil : (excess.sum / excess.size).round(2)
      }
    end
  end
end
