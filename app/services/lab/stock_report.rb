module Lab
  # One stock's strategy backtest over all stored history (Scans::History's archive plus
  # regular prices): which entry signals made money on this stock, where, and by year.
  #
  # Signals: the Indicator Scanner's six (each also only on Crossovers::STRONG_VOLUME x
  # volume), MACD (12, 26, 9) crossing its signal line, a close back above the lower
  # Bollinger band (20, 2), a close above the prior 20-session high (also on volume), a
  # golden cross of the 50- and 200-day averages, and Lab::Strategies' RSI and range
  # strategies with their own rules.
  #
  # Every other signal is traded the same way: buy at the next open (skipped when it
  # opens more than MAX_GAP_PCT above the signal close), stop just under the 10-session
  # low (at most MAX_STOP_PCT away), target REWARD_MULTIPLE x the risk, out after HOLD
  # sessions; COST_PCT round trip; trades never overlap. Rule checks, not advice.
  module StockReport
    HOLD = 20
    MAX_GAP_PCT = 3.0
    MAX_STOP_PCT = 8.0
    REWARD_MULTIPLE = 2.0
    COST_PCT = Strategies::COST_PCT
    MIN_BARS = 60

    LABELS = {
      "scan_ema_9_21" => "EMA 9/21 cross", "scan_ema_stack" => "EMA 9 > 21 > 50 stack", "scan_hma_up" => "HMA 55 turns up",
      "scan_alma_cross" => "Close above ALMA 21", "scan_aroon_cross" => "Aroon Up crosses Down", "scan_aroon_strong" => "Aroon Up ≥ 70",
      "macd_cross" => "MACD crosses its signal", "bollinger_bounce" => "Bollinger lower-band bounce", "breakout_20d" => "20-day high breakout",
      "breakout_20d_vol" => "20-day breakout on 1.5× volume", "golden_cross" => "Golden cross (50/200)",
      "lab_rsi_reversion" => "RSI mean reversion (Lab)", "lab_range_grid" => "Range bounce (Lab)"
    }.merge(Scans::Crossovers::SIGNALS.to_h { |k| [ "scan_#{k}_vol", nil ] }).freeze

    module_function

    def cached(symbol)
      stock = Stock.find_by(symbol: symbol.to_s.upcase) or return
      Rails.cache.fetch([ "lab/stock_report", 1, stock.id, StockDailyPrice.where(stock: stock).maximum(:traded_on) ], expires_in: 12.hours) { call(stock) }
    end

    def call(stock)
      rows = history(stock)
      return { symbol: stock.symbol, name: stock.name, sector: stock.sector, sessions: rows.size, error: "Not enough price history (#{rows.size} sessions)" } if rows.size < MIN_BARS

      x = Scans::Crossovers.compute(rows)
      lab = Strategies.prepare(rows)
      closes, dates = x[:close], x[:dates]
      indicators = classic_indicators(closes)
      signals = entry_signals(x, lab, indicators)
      trades = signals.to_h { |key, idx| [ key, run(x, idx) ] }
      Strategies::KEYS.each do |key|
        list, starts = lab_trades(lab, key)
        trades["lab_#{key}"] = list
        signals["lab_#{key}"] = starts
      end

      {
        symbol: stock.symbol, name: stock.name, sector: stock.sector, sessions: closes.size, from: dates.first, to: dates.last, close: closes.last.round(2),
        rules: { hold: HOLD, max_stop_pct: MAX_STOP_PCT, reward_multiple: REWARD_MULTIPLE, cost_pct: COST_PCT, max_gap_pct: MAX_GAP_PCT },
        buy_hold: buy_hold(closes, dates),
        baseline: { 20 => forward(closes, (0...closes.size).to_a, 20) },
        strategies: signals.keys.map { |key| strategy_row(key, signals[key], trades[key], closes, dates) }
                            .sort_by { |s| [ s[:stats][:trades].zero? ? 1 : 0, -(s[:stats][:profit_factor] || -1) ] },
        trades: trades.flat_map { |key, list| list.map { trade_row(key, _1, dates) } },
        prices: dates.each_index.map { |i| { date: dates[i], close: closes[i].round(2) } },
        now: now(stock, lab, indicators)
      }
    end

    def history(stock)
      cols = Scans::History::COLUMNS
      regular = StockDailyPrice.where(stock: stock).where("close_price > 0")
      regular = regular.where(traded_on: ...Nepse::MarketHours.today) if Nepse::MarketHours.sync_window?
      regular = regular.order(:traded_on).pluck(*cols)
      first = regular.first&.at(1)
      archived = StockPriceArchive.where(stock: stock)
      archived = archived.where(traded_on: ...first) if first
      (archived.order(:traded_on).pluck(*cols) + regular).map { |_, d, h, l, c, o, v| [ d, h || 0.0, l || 0.0, c, o || 0.0, v || 0 ] }
    end

    def classic_indicators(closes)
      ema12 = Indicators::Trend.ema(closes, 12)
      ema26 = Indicators::Trend.ema(closes, 26)
      macd = closes.each_index.map { |i| ema12[i] && ema26[i] ? ema12[i] - ema26[i] : nil }
      signal = Array.new(closes.size)
      if (start = macd.index { _1 })
        Indicators::Trend.ema(macd[start..], 9).each_with_index { |v, k| signal[start + k] = v }
      end
      sma20 = Strategies.sma(closes, 20)
      lower = closes.each_index.map do |i|
        next if i < 19

        window = closes[(i - 19)..i]
        mean = window.sum / 20
        sma20[i] - 2 * Math.sqrt(window.sum { (_1 - mean)**2 } / 20)
      end
      { macd: macd, macd_signal: signal, bb_lower: lower, sma20: sma20 }
    end

    def entry_signals(x, lab, ind)
      n = x[:close].size
      crosses_up = ->(a, b, i) { i.positive? && [ a[i], b[i], a[i - 1], b[i - 1] ].none?(&:nil?) && a[i] > b[i] && a[i - 1] <= b[i - 1] }
      on_volume = ->(i) { (Scans::Crossovers.volume_ratio(x, i) || 0) >= Scans::Crossovers::STRONG_VOLUME }
      signals = {}
      Scans::Crossovers::SIGNALS.each do |k|
        signals["scan_#{k}"] = Scans::Crossovers.onsets(x, k)
        signals["scan_#{k}_vol"] = signals["scan_#{k}"].select(&on_volume)
      end
      signals["macd_cross"] = (1...n).select { crosses_up.(ind[:macd], ind[:macd_signal], _1) }
      signals["bollinger_bounce"] = (1...n).select { |i| ind[:bb_lower][i] && ind[:bb_lower][i - 1] && x[:close][i - 1] < ind[:bb_lower][i - 1] && x[:close][i] > ind[:bb_lower][i] }
      signals["breakout_20d"] = (21...n).select { |i| x[:close][i] > x[:high][(i - 20)...i].max && x[:close][i - 1] <= x[:high][(i - 21)...(i - 1)].max }
      signals["breakout_20d_vol"] = signals["breakout_20d"].select(&on_volume)
      signals["golden_cross"] = (1...n).select { crosses_up.(lab[:sma50], lab[:sma200], _1) }
      signals
    end

    # Non-overlapping trades from signal bars.
    def run(x, indices)
      trades = []
      busy_until = -1
      indices.each do |i|
        next if i <= busy_until

        trade = simulate(x, i) or next
        trades << trade
        busy_until = trade[:exit_index]
      end
      trades
    end

    def simulate(x, i)
      j = i + 1
      return if j >= x[:close].size

      entry = x[:open][j]
      return if entry > x[:close][i] * (1 + MAX_GAP_PCT / 100)

      stop = [ x[:low][[ i - 9, 0 ].max..i].min * 0.99, entry * (1 - MAX_STOP_PCT / 100) ].max
      return if stop >= entry || (entry - stop) / entry * 100 < Strategies::MIN_RISK_PCT

      target = entry + REWARD_MULTIPLE * (entry - stop)
      last = [ j + HOLD - 1, x[:close].size - 1 ].min
      (j..last).each do |k|
        price, reason =
          if x[:low][k] <= stop then [ k > j && x[:open][k] < stop ? x[:open][k] : stop, "stop" ]
          elsif x[:high][k] >= target then [ k > j && x[:open][k] > target ? x[:open][k] : target, "target" ]
          elsif k == j + HOLD - 1 then [ x[:close][k], "time" ]
          end
        return { entry_index: j, exit_index: k, entry: entry, exit: price, reason: reason, return_pct: (price / entry - 1) * 100 - COST_PCT } if price
      end
      { entry_index: j, exit_index: last, entry: entry, exit: x[:close][last], reason: "open", return_pct: (x[:close][last] / entry - 1) * 100, open: true }
    end

    def lab_trades(lab, key)
      trades = []
      starts = []
      busy_until = -1
      n = lab[:close].size
      (1...(n - 1)).each do |i|
        next if i <= busy_until

        levels = Strategies.trigger(lab, key, i) or next
        t = Strategies.simulate(lab, key, i, levels)
        next unless %i[closed open].include?(t[:status])

        starts << i
        trades << { entry_index: t[:entry_index], exit_index: t[:exit_index], entry: t[:entry], exit: t[:exit], reason: t[:reason] || "open",
                    return_pct: t[:return_pct], open: t[:status] == :open }
        busy_until = t[:status] == :open ? n : t[:exit_index]
      end
      [ trades, starts ]
    end

    def strategy_row(key, indices, trades, closes, dates)
      {
        key: key, label: label(key), family: key.start_with?("scan_") ? "Indicator Scanner" : key.start_with?("lab_") ? "Strategy Lab" : "Classic",
        signals: indices.size, latest_signal: indices.max && dates[indices.max], sessions_since_signal: indices.max && closes.size - 1 - indices.max,
        forward20: forward(closes, indices, 20), stats: stats(trades, dates)
      }
    end

    def label(key)
      LABELS[key] || (key.end_with?("_vol") ? "#{LABELS[key.delete_suffix('_vol')]} on 1.5× volume" : key)
    end

    def stats(trades, dates)
      closed = trades.reject { _1[:open] }
      return { trades: 0, open: trades.size } if closed.empty?

      returns = closed.map { _1[:return_pct] }
      wins = returns.select(&:positive?)
      losses = returns.reject(&:positive?)
      equity = peak = 1.0
      drawdown = 0.0
      closed.each do |t|
        equity *= 1 + t[:return_pct] / 100
        peak = [ peak, equity ].max
        drawdown = [ drawdown, (equity / peak - 1) * 100 ].min
      end
      {
        trades: closed.size, open: trades.size - closed.size, win_rate_pct: (wins.size * 100.0 / closed.size).round(1),
        profit_factor: losses.sum.zero? ? nil : (wins.sum / -losses.sum).round(2), avg_return_pct: (returns.sum / closed.size).round(2),
        total_return_pct: ((equity - 1) * 100).round(1), max_drawdown_pct: drawdown.round(1),
        best_pct: returns.max.round(2), worst_pct: returns.min.round(2),
        avg_hold: (closed.sum { _1[:exit_index] - _1[:entry_index] + 1 } / closed.size.to_f).round(1),
        by_year: closed.group_by { dates[_1[:entry_index]].year }.sort.to_h.transform_values do |list|
          { trades: list.size, total_return_pct: ((list.reduce(1.0) { |e, t| e * (1 + t[:return_pct] / 100) } - 1) * 100).round(1) }
        end
      }
    end

    # One trade for the log: the session the signal fired, the buy (next open) and the
    # sell, how long it was held (trading sessions, counting the buy and sell days, and
    # calendar days) and why it ended. An open trade is marked to the latest close.
    def trade_row(key, t, dates)
      last = dates[t[:exit_index]]
      {
        key: key, signal_on: dates[t[:entry_index] - 1], entry_on: dates[t[:entry_index]], exit_on: t[:open] ? nil : last,
        entry: t[:entry].round(2), exit: t[:exit].round(2), return_pct: t[:return_pct].round(2), reason: t[:reason], open: !!t[:open],
        held_sessions: t[:exit_index] - t[:entry_index] + 1, held_days: (last - dates[t[:entry_index]]).to_i
      }
    end

    def forward(closes, indices, sessions)
      values = indices.filter_map { |i| i + sessions < closes.size ? (closes[i + sessions] / closes[i] - 1) * 100 : nil }
      return if values.empty?

      { count: values.size, avg_pct: (values.sum / values.size).round(2), up_pct: (values.count(&:positive?) * 100.0 / values.size).round(1) }
    end

    def buy_hold(closes, dates)
      peak = 0.0
      drawdown = 0.0
      closes.each do |c|
        peak = [ peak, c ].max
        drawdown = [ drawdown, (c / peak - 1) * 100 ].min
      end
      {
        return_pct: ((closes.last / closes.first - 1) * 100).round(1), max_drawdown_pct: drawdown.round(1),
        by_year: dates.each_index.group_by { dates[_1].year }.transform_values { |ix| ((closes[ix.last] / closes[ix.first] - 1) * 100).round(1) }
      }
    end

    def now(stock, lab, ind)
      row = Scans::Cache.scan[:rows].find { _1[:symbol] == stock.symbol }
      snapshot = stock.setup_snapshots.order(traded_on: :desc).first
      closes = lab[:close]
      {
        rsi: lab[:rsi].last&.round(1), sma50: lab[:sma50].last&.round(2), sma200: lab[:sma200].last&.round(2),
        macd: ind[:macd].last&.round(2), macd_signal: ind[:macd_signal].last&.round(2), bb_lower: ind[:bb_lower].last&.round(2),
        high_52w: closes.last(250).max.round(2), low_52w: closes.last(250).min.round(2),
        levels: row&.dig(:levels), readiness: snapshot&.readiness_score, trend_rules_passed: snapshot&.trend_rules_passed,
        rs_rating: snapshot.respond_to?(:rs_rating) ? snapshot&.rs_rating : nil, in_buy_zone: snapshot&.in_buy_zone
      }
    end
  end
end
