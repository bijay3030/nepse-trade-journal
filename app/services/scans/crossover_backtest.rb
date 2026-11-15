module Scans
  # How each Scans::Crossovers signal played out on NEPSE history since 2020 (archived
  # prices plus the regular ones, Scans::History): every session where a signal began is
  # a sample, and its return over the next 5, 10 and 20 sessions (close to close, before
  # costs) is compared with all stock-days (the baseline), overall, by year, and for
  # signals that began on STRONG_VOLUME x average volume. Indicators only use bars up to
  # the signal day, so there's no look-ahead. Stocks are processed one at a time.
  module CrossoverBacktest
    HORIZONS = [ 5, 10, 20 ].freeze
    YEAR_HORIZON = 20
    # Trades with Scans::Levels' crossover levels, on the board backtest's terms.
    MAX_HOLD = Backtest::Runner::MAX_HOLD
    COST_PCT = Backtest::Runner::ROUND_TRIP_COST_PCT
    MIN_RISK_PCT = Backtest::Runner::MIN_RISK_PCT

    # Running count / sum / wins, so seven years of samples aren't kept in memory.
    class Tally
      def initialize = @n = @sum = @wins = 0
      def add(value)
        @n += 1
        @sum += value
        @wins += 1 if value.positive?
      end

      def to_h
        return { n: 0 } if @n.zero?

        { n: @n, avg_return_pct: (@sum / @n).round(2), win_rate_pct: (@wins * 100.0 / @n).round(1) }
      end
    end

    module_function

    def call(now: Time.current)
      keys = [ "all" ] + Crossovers::SIGNALS
      tallies = keys.to_h { |key| [ key, HORIZONS.to_h { [ _1, Tally.new ] } ] }
      with_volume = Crossovers::SIGNALS.to_h { |key| [ key, HORIZONS.to_h { [ _1, Tally.new ] } ] }
      years = Hash.new { |h, key| h[key] = Hash.new { |y, year| y[year] = Tally.new } }
      trades = Hash.new { |h, k| h[k] = [] }
      first = last = nil

      History.each_stock(now: now) do |_stock_id, rows|
        next if rows.size < Crossovers::MIN_BARS

        series = Crossovers.compute(rows)
        closes = series[:close]
        first = [ first, series[:dates].first ].compact.min
        last = [ last, series[:dates].last ].compact.max
        add = lambda do |key, i, volume_ok|
          HORIZONS.each do |h|
            next if i + h >= closes.size || !closes[i].positive?

            value = (closes[i + h] / closes[i] - 1) * 100
            tallies[key][h].add(value)
            with_volume[key][h].add(value) if volume_ok
            years[key][series[:dates][i].year].add(value) if h == YEAR_HORIZON
          end
        end
        (0...closes.size).each { |i| add.("all", i, false) }
        Crossovers::SIGNALS.each do |signal|
          busy_until = -1
          Crossovers.onsets(series, signal).each do |i|
            ratio = Crossovers.volume_ratio(series, i)
            add.(signal, i, ratio && ratio >= Crossovers::STRONG_VOLUME)
            next if i <= busy_until

            trade = simulate(series, i) or next
            trades[signal] << trade
            busy_until = trade[:exit_index] if trade[:status] == :closed
            busy_until = series[:close].size if trade[:status] == :open
          end
        end
      end

      {
        period: { from: first, to: last }, horizons: HORIZONS, year_horizon: YEAR_HORIZON, strong_volume: Crossovers::STRONG_VOLUME,
        signals: tallies.transform_values { |by_h| by_h.transform_values(&:to_h) },
        signals_with_volume: with_volume.transform_values { |by_h| by_h.transform_values(&:to_h) },
        by_year: keys.to_h { |key| [ key, years[key].sort.to_h.transform_values(&:to_h) ] },
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

  end
end
