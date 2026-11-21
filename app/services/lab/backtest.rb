module Lab
  # Runs Lab::Strategies on every stock's history since 2020 (Scans::History), one stock
  # at a time, and returns:
  #
  #   leaderboard  each strategy across the market: trades, win rate, profit factor,
  #                average return and R, compounded max drawdown, by year and by NEPSE's
  #                phase on the signal day (Scans::MarketPhase)
  #   candidates   stocks where a strategy triggers on the latest session AND its record
  #                on that stock qualifies: MIN_TRADES closed trades, profit factor above
  #                MIN_PROFIT_FACTOR, and still positive on trades since OOS_FROM (an
  #                out-of-sample check on the last two years). Thinly traded stocks are
  #                left out.
  #   qualifying   per strategy, the stocks whose record qualifies (whether or not it
  #                triggers today): the watch list candidates come from
  #   paper        for the given paper trades, their current state, re-simulated with
  #                the same rules on the data since their signal (Lab::PaperTrades)
  #
  # Trades on one stock don't overlap (a trigger during an open trade is ignored).
  module Backtest
    OOS_FROM = Date.new(2025, 1, 1)
    MIN_TRADES = 10
    MIN_PROFIT_FACTOR = 1.3
    MIN_OOS_TRADES = 3

    module_function

    def call(now: Time.current, paper: {})
      phase_on = Scans::MarketPhase.timeline
      latest = StockSetupSnapshot.maximum(:traded_on)
      snapshots = latest ? StockSetupSnapshot.where(traded_on: latest).pluck(:stock_id, :guards, :readiness_score).to_h { |id, guards, readiness| [ id, { guards: guards, readiness: readiness } ] } : {}
      market = Strategies::KEYS.index_with { [] }
      candidates = []
      qualifying = Strategies::KEYS.index_with { [] }
      updates = []
      as_of = nil

      Scans::History.each_stock(now: now) do |stock_id, rows|
        next if rows.size < Strategies::MIN_BARS

        s = Strategies.prepare(rows)
        last = s[:close].size - 1
        as_of = [ as_of, s[:dates][last] ].compact.max
        Strategies::KEYS.each do |key|
          trades = run(s, key)
          market[key].concat(trades.map { |t| { return_pct: t[:return_pct], r: t[:r], on: t[:entry_on], phase: phase_on[s[:dates][t[:entry_index] - 1]] } })
          record = stats(trades)
          info = snapshots[stock_id] || {}
          next unless qualifies?(record) && !Array(info[:guards]).include?("thin_volume")

          qualifying[key] << { stock_id: stock_id, trades: record[:trades], profit_factor: record[:profit_factor] }
          today = Strategies.trigger(s, key, last)
          next unless today

          candidates << { stock_id: stock_id, strategy: key, signal_on: s[:dates][last], close: s[:close][last].round(2),
                          change_pct: last.positive? ? ((s[:close][last] / s[:close][last - 1] - 1) * 100).round(2) : nil,
                          rsi: s[:rsi][last], levels: today, record: record, readiness: info[:readiness], guards: Array(info[:guards]) }
        end
        Array(paper[stock_id]).each do |trade|
          i = s[:dates].index(trade.signal_on) or next
          updates << [ trade, Strategies.simulate(s, trade.strategy, i, trade.levels) ]
        end
      end

      stocks = Stock.where(id: (candidates + qualifying.values.flatten).map { _1[:stock_id] }).pluck(:id, :symbol, :name, :sector).to_h { |id, *rest| [ id, rest ] }
      {
        as_of: as_of, period: { from: Scans::History::ARCHIVE_FROM, to: as_of }, oos_from: OOS_FROM,
        rules: { min_trades: MIN_TRADES, min_profit_factor: MIN_PROFIT_FACTOR, min_oos_trades: MIN_OOS_TRADES, cost_pct: Strategies::COST_PCT },
        strategies: Strategies::KEYS.map { { key: _1, label: Strategies::LABELS[_1], hold: Strategies::HOLD[_1] } },
        leaderboard: market.to_h { |key, trades| [ key, leaderboard(trades) ] },
        candidates: candidates.map { |c| c.merge(symbol: stocks.dig(c[:stock_id], 0), name: stocks.dig(c[:stock_id], 1), sector: stocks.dig(c[:stock_id], 2)) }
                              .sort_by { [ -_1[:record][:profit_factor].to_f, _1[:symbol].to_s ] },
        qualifying: qualifying.transform_values do |list|
          list.map { _1.except(:stock_id).merge(symbol: stocks.dig(_1[:stock_id], 0)) }.sort_by { -_1[:profit_factor].to_f }
        end,
        paper: updates
      }
    end

    # Closed trades of one strategy on one stock, without overlap.
    def run(s, key)
      trades = []
      busy_until = -1
      (Strategies::MIN_BARS..(s[:close].size - 2)).each do |i|
        next if i <= busy_until

        levels = Strategies.trigger(s, key, i) or next
        trade = Strategies.simulate(s, key, i, levels)
        busy_until = trade[:exit_index] if trade[:status] == :closed
        busy_until = s[:close].size if trade[:status] == :open
        trades << trade if trade[:status] == :closed
      end
      trades
    end

    def qualifies?(record)
      record[:trades] >= MIN_TRADES && record[:profit_factor].to_f > MIN_PROFIT_FACTOR &&
        record.dig(:oos, :trades).to_i >= MIN_OOS_TRADES && record.dig(:oos, :avg_return_pct).to_f.positive?
    end

    def stats(trades)
      summary(trades).merge(oos: summary(trades.select { _1[:entry_on] >= OOS_FROM }).slice(:trades, :win_rate_pct, :avg_return_pct, :profit_factor))
    end

    def leaderboard(trades)
      # No drawdown here: trades across stocks overlap in time, so compounding them in a row means little.
      summary(trades).except(:max_drawdown_pct).merge(
        oos: summary(trades.select { _1[:on] >= OOS_FROM }).slice(:trades, :win_rate_pct, :avg_return_pct, :profit_factor),
        by_year: trades.group_by { _1[:on].year }.sort.to_h.transform_values { summary(_1).slice(:trades, :win_rate_pct, :avg_return_pct, :profit_factor) },
        by_phase: Scans::MarketPhase::PHASES.index_with { |p| summary(trades.select { _1[:phase] == p }).slice(:trades, :win_rate_pct, :avg_return_pct, :profit_factor) }
      )
    end

    # trades: [{ return_pct:, r:, (entry_on: | on:) }, ...] in time order per stock.
    def summary(trades)
      return { trades: 0 } if trades.empty?

      returns = trades.map { _1[:return_pct].to_f }
      wins = returns.select(&:positive?)
      losses = returns.reject(&:positive?)
      equity = peak = 1.0
      drawdown = 0.0
      trades.sort_by { _1[:entry_on] || _1[:on] }.each do |t|
        equity *= 1 + t[:return_pct].to_f / 100
        peak = [ peak, equity ].max
        drawdown = [ drawdown, (equity / peak - 1) * 100 ].min
      end
      {
        trades: trades.size, win_rate_pct: (wins.size * 100.0 / trades.size).round(1),
        avg_return_pct: (returns.sum / trades.size).round(2), avg_r: (trades.sum { _1[:r].to_f } / trades.size).round(2),
        profit_factor: losses.sum.zero? ? nil : (wins.sum / -losses.sum).round(2), max_drawdown_pct: drawdown.round(1)
      }
    end
  end
end
