module Backtest
  # Tests the app's signals against what happened next, using the point-in-time
  # snapshots (Setups::HistoryBuilder), so no signal used information from after
  # its own session.
  #
  # 1. Forward returns: for each snapshot, the close-to-close return after 5, 10
  #    and 20 sessions and NEPSE's return over the same sessions, grouped by
  #    readiness band, zone state, broker flow, trend rules, the entry-zone flag,
  #    and, for charts meeting the entry rules, which tradability guard held them back.
  # 2. Trades: every "Entry zone now" signal, one open trade per stock at a time.
  #    Signals held back by a guard (Setups::Guards: thin volume, near a circuit)
  #    are not traded and are counted.
  #    Entry at the next session's open; exit at the invalidation stop or the
  #    target (a gap through either exits at that day's open; stop and target on
  #    the same day counts as the stop), or at the close after MAX_HOLD sessions.
  #    Returns are net of a round-trip cost (commission, SEBON fee, DP charge).
  #    Entries under MIN_RISK_PCT above the stop are skipped and counted.
  class Runner
    HORIZONS = [ 5, 10, 20 ].freeze
    MAX_HOLD = 20
    ROUND_TRIP_COST_PCT = 0.8
    # Entries less than this far above the stop are skipped: a stop 0.1% away isn't a
    # tradeable plan, and dividing by that tiny risk makes R multiples meaningless.
    MIN_RISK_PCT = 1.0
    READINESS_BANDS = { "0-19" => 0..19, "20-39" => 20..39, "40-59" => 40..59, "60+" => 60..100 }.freeze

    def self.call(**options) = new(**options).call

    def initialize(cost_pct: ROUND_TRIP_COST_PCT, max_hold: MAX_HOLD, save: true)
      @cost = cost_pct.to_f / 100
      @max_hold = max_hold.to_i
      @save = save
    end

    def call
      snapshots = StockSetupSnapshot.order(:traded_on).pluck(
        :stock_id, :traded_on, :close_price, :readiness_score, :zone_state, :flow_state, :trend_rules_passed,
        :in_buy_zone, :entry_zone_low, :entry_zone_high, :invalidation_price, :target_price, :setup_type, :guards
      ).map { |row| snapshot_hash(row) }
      sessions = Setups::HistoryBuilder.sessions.to_set
      snapshots.select! { sessions.include?(_1[:traded_on]) }
      return { success: false, error: "No snapshots. Run rails nepse:data:setup_history first." } if snapshots.empty?

      load_prices(snapshots.map { _1[:stock_id] }.uniq)
      load_nepse

      results = {
        period: { from: snapshots.first[:traded_on], to: snapshots.last[:traded_on], sessions: snapshots.map { _1[:traded_on] }.uniq.size,
                  snapshots: snapshots.size, stocks: snapshots.map { _1[:stock_id] }.uniq.size },
        baseline: baseline(snapshots),
        groups: groups(snapshots),
        trades: trades(snapshots)
      }
      run = persist(results) if @save
      { success: true, run_id: run&.id, **results }
    end

    private

    def snapshot_hash(row)
      keys = %i[stock_id traded_on close readiness zone_state flow_state trend_rules in_buy_zone entry_low entry_high stop target setup_type guards]
      keys.zip(row).to_h.tap do |snap|
        %i[close entry_low entry_high stop target].each { snap[_1] = snap[_1]&.to_f }
      end
    end

    # stock_id => { dates: [...], index: { date => i }, bars: [[open, high, low, close], ...] }
    def load_prices(stock_ids)
      @prices = StockDailyPrice.where(stock_id: stock_ids).order(:traded_on)
        .pluck(:stock_id, :traded_on, :open_price, :high_price, :low_price, :close_price)
        .group_by(&:first).transform_values do |rows|
          dates = rows.map { _1[1] }
          { dates: dates, index: dates.each_with_index.to_h, bars: rows.map { _1[2..].map(&:to_f) } }
        end
    end

    def load_nepse
      @nepse = MarketIndex.find_by(symbol: "NEPSE")&.histories&.pluck(:traded_on, :index_value)&.to_h { [ _1, _2.to_f ] } || {}
    end

    # Close-to-close return after `horizon` sessions and NEPSE's over the same dates.
    def forward(snap, horizon)
      series = @prices[snap[:stock_id]] or return
      i = series[:index][snap[:traded_on]] or return
      j = i + horizon
      return if j >= series[:dates].size

      start, finish = series[:bars][i][3], series[:bars][j][3]
      return unless start.positive?

      stock_return = finish / start - 1
      a, b = @nepse[snap[:traded_on]], @nepse[series[:dates][j]]
      nepse_return = a && b && a.positive? ? b / a - 1 : nil
      [ stock_return, nepse_return ]
    end

    def summarize(samples)
      returns = samples.map(&:first)
      excess = samples.filter_map { |r, n| n && r - n }
      return { n: 0 } if returns.empty?

      sorted = returns.sort
      {
        n: returns.size,
        avg_return_pct: pct(returns.sum / returns.size),
        median_return_pct: pct(sorted[sorted.size / 2]),
        win_rate_pct: (returns.count(&:positive?).to_f / returns.size * 100).round(1),
        avg_excess_pct: excess.empty? ? nil : pct(excess.sum / excess.size)
      }
    end

    def by_horizon(snapshots)
      HORIZONS.to_h { |h| [ h, summarize(snapshots.filter_map { forward(_1, h) }) ] }
    end

    def baseline(snapshots) = by_horizon(snapshots)

    def groups(snapshots)
      {
        readiness: READINESS_BANDS.to_h { |band, range| [ band, by_horizon(snapshots.select { range.cover?(_1[:readiness].to_i) }) ] },
        zone_state: snapshots.group_by { _1[:zone_state] }.sort.to_h.transform_values { by_horizon(_1) },
        # Setup type of the stocks inside their entry zone (where the type drives the signal).
        setup_type: snapshots.select { _1[:zone_state] == "in_zone" }.group_by { _1[:setup_type] || "none" }.sort.to_h.transform_values { by_horizon(_1) },
        flow_state: snapshots.group_by { _1[:flow_state] || "no_data" }.sort.to_h.transform_values { by_horizon(_1) },
        trend: { "5+ of 7 rules" => by_horizon(snapshots.select { _1[:trend_rules].to_i >= 5 }),
                 "under 5" => by_horizon(snapshots.select { _1[:trend_rules].to_i < 5 }) },
        entry_zone: { "Entry zone now" => by_horizon(snapshots.select { _1[:in_buy_zone] }),
                      "Everything else" => by_horizon(snapshots.reject { _1[:in_buy_zone] }) },
        guards: guard_groups(snapshots)
      }
    end

    # Charts that met the entry rules, split by whether a guard held them back.
    def guard_groups(snapshots)
      qualified = snapshots.select { qualifies?(_1) }
      { "Passed guards" => by_horizon(qualified.select { _1[:guards].empty? }) }
        .merge(Setups::Guards::ALL.to_h { |guard| [ guard, by_horizon(qualified.select { _1[:guards].include?(guard) }) ] })
    end

    def qualifies?(snap)
      Setups::Readiness.in_buy_zone?(zone_state: snap[:zone_state], price_rules_passed: snap[:trend_rules].to_i, score: snap[:readiness].to_i)
    end

    def trades(snapshots)
      symbols = Stock.where(id: snapshots.map { _1[:stock_id] }.uniq).pluck(:id, :symbol).to_h
      trades = []
      snapshots.select { _1[:in_buy_zone] }.group_by { _1[:stock_id] }.each do |stock_id, signals|
        busy_until = nil
        signals.each do |signal|
          next if busy_until && signal[:traded_on] <= busy_until

          trade = simulate(signal)
          next unless trade

          trades << trade.merge(symbol: symbols[stock_id], setup_type: signal[:setup_type])
          next if trade[:status] == "skipped"

          busy_until = trade[:exit_on] || Date::Infinity.new
        end
      end
      trade_stats(trades.sort_by { _1[:signal_on] }).merge(
        held_back: Setups::Guards::ALL.to_h { |guard| [ guard, snapshots.count { qualifies?(_1) && _1[:guards].include?(guard) } ] }
      )
    end

    def simulate(signal)
      series = @prices[signal[:stock_id]] or return
      i = series[:index][signal[:traded_on]] or return
      return if i + 1 >= series[:dates].size || !signal[:stop] || !signal[:target]

      entry = series[:bars][i + 1][0]
      stop, target = signal[:stop], signal[:target]
      return unless entry.positive?

      base = { signal_on: signal[:traded_on], entry_on: series[:dates][i + 1], entry: entry.round(2), stop: stop, target: target }
      return base.merge(status: "skipped") if (entry - stop) / entry * 100 < MIN_RISK_PCT

      exit_price = exit_on = reason = nil
      (i + 1..[ i + @max_hold, series[:dates].size - 1 ].min).each do |j|
        open, high, low, close = series[:bars][j]
        if low <= stop
          exit_price, reason = [ j > i + 1 && open < stop ? open : stop, "stop" ]
        elsif high >= target
          exit_price, reason = [ j > i + 1 && open > target ? open : target, "target" ]
        elsif j == i + @max_hold
          exit_price, reason = [ close, "time" ]
        end
        next unless exit_price

        exit_on = series[:dates][j]
        break
      end

      return base.merge(status: "open") unless exit_price

      gross = exit_price / entry - 1
      base.merge(
        status: "closed", exit_on: exit_on, exit: exit_price.round(2), exit_reason: reason,
        return_pct: pct(gross - @cost), r_multiple: ((exit_price - entry) / (entry - stop)).round(2),
        sessions_held: series[:index][exit_on] - (i + 1) + 1
      )
    end

    def trade_stats(trades)
      closed = trades.select { _1[:status] == "closed" }
      skipped = trades.count { _1[:status] == "skipped" }
      trades = trades.reject { _1[:status] == "skipped" }
      r_values = closed.map { _1[:r_multiple] }.sort
      returns = closed.map { _1[:return_pct] }
      wins = returns.select(&:positive?)
      losses = returns.reject(&:positive?)
      {
        total: trades.size, closed: closed.size, open: trades.size - closed.size, skipped: skipped,
        min_risk_pct: MIN_RISK_PCT,
        win_rate_pct: closed.empty? ? nil : (wins.size.to_f / closed.size * 100).round(1),
        avg_return_pct: closed.empty? ? nil : (returns.sum / closed.size).round(2),
        avg_r: closed.empty? ? nil : (r_values.sum / closed.size).round(2),
        median_r: r_values.empty? ? nil : r_values[r_values.size / 2],
        avg_win_pct: wins.empty? ? nil : (wins.sum / wins.size).round(2),
        avg_loss_pct: losses.empty? ? nil : (losses.sum / losses.size).round(2),
        profit_factor: losses.sum.zero? ? nil : (wins.sum / -losses.sum).round(2),
        avg_sessions_held: closed.empty? ? nil : (closed.sum { _1[:sessions_held] }.to_f / closed.size).round(1),
        exits: closed.map { _1[:exit_reason] }.tally,
        by_setup_type: closed.group_by { _1[:setup_type] }.transform_values do |group|
          { closed: group.size, win_rate_pct: (group.count { _1[:return_pct].positive? }.to_f / group.size * 100).round(1),
            avg_return_pct: (group.sum { _1[:return_pct] } / group.size).round(2) }
        end,
        list: trades.last(200)
      }
    end

    def persist(results)
      BacktestRun.create!(
        from_date: results[:period][:from], to_date: results[:period][:to], sessions: results[:period][:sessions],
        parameters: { horizons: HORIZONS, max_hold: @max_hold, round_trip_cost_pct: (@cost * 100).round(2), readiness_bands: READINESS_BANDS.keys },
        results: results
      )
    end

    def pct(value) = (value * 100).round(2)
  end
end
