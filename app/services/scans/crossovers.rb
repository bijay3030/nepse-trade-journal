module Scans
  # Trend-indicator signals for every active equity, on completed sessions only (during
  # market hours today's still-moving bar is left out, like the board):
  #
  #   ema_9_21     EMA 9 crossed above EMA 21 (and is still above)
  #   ema_21_50    EMA 21 crossed above EMA 50 (and is still above)
  #   ema_stack    EMA 9 > EMA 21 > EMA 50 (age = sessions since it formed)
  #   hma_up       HMA 21 turned from falling to rising (and is still rising)
  #   alma_cross   close crossed above ALMA 9 (and is still above)
  #   aroon_cross  Aroon Up crossed above Aroon Down (and is still above)
  #   aroon_strong Aroon Up at or above STRONG_AROON (age = sessions since it got there)
  #
  # Each signal's value is its age in sessions (0 = the latest session) or nil. The page
  # filters by age ("within N sessions"). Settings are TradingView's defaults.
  module Crossovers
    SIGNALS = %w[ema_9_21 ema_21_50 ema_stack hma_up alma_cross aroon_cross aroon_strong].freeze
    PARAMS = { ema: [ 9, 21, 50 ], hma: 21, alma: { length: 9, offset: 0.85, sigma: 6.0 }, aroon: 25 }.freeze
    STRONG_AROON = 70.0
    MIN_BARS = 60
    CHART_SESSIONS = 260
    HISTORY_DAYS = 500

    module_function

    def call(now: Time.current)
      bars = load_bars(now)
      as_of = bars.values.filter_map { _1.last&.first }.max
      snapshots = latest_snapshots
      stocks = Stock.where(id: bars.keys).pluck(:id, :symbol, :name, :sector).to_h { |id, *rest| [ id, rest ] }
      rows = bars.filter_map do |stock_id, rows_for_stock|
        next if rows_for_stock.size < MIN_BARS || rows_for_stock.last.first != as_of

        symbol, name, sector = stocks[stock_id]
        series = compute(rows_for_stock)
        closes = series[:close]
        {
          symbol: symbol, name: name, sector: sector,
          close: closes.last.round(2), change_pct: closes[-2]&.positive? ? ((closes[-1] / closes[-2] - 1) * 100).round(2) : nil,
          signals: SIGNALS.to_h { [ _1, latest_age(series, _1) ] },
          values: values(series),
          **snapshots.fetch(stock_id, {})
        }
      end
      { as_of: as_of, params: PARAMS, strong_aroon: STRONG_AROON, rows: rows.sort_by { _1[:symbol] } }
    end

    # { stock_id => [[date, high, low, close], ...] } oldest first, completed sessions.
    def load_bars(now)
      scope = StockDailyPrice.joins(:stock).merge(Stock.active.where(security_type: "Equity"))
                             .where(traded_on: (Nepse::MarketHours.today(now) - HISTORY_DAYS)..)
                             .where("stock_daily_prices.close_price > 0")
      scope = scope.where(traded_on: ...Nepse::MarketHours.today(now)) if Nepse::MarketHours.sync_window?(now)
      scope.order(:traded_on).pluck(:stock_id, :traded_on, :high_price, :low_price, :close_price)
           .group_by(&:first).transform_values { |rows| rows.map { |_, d, h, l, c| [ d, h.to_f, l.to_f, c.to_f ] } }
    end

    def compute(rows)
      closes = rows.map { _1[3] }
      highs = rows.map { [ _1[1], _1[3] ].max }
      lows = rows.map { [ _1[2].positive? ? _1[2] : _1[3], _1[3] ].min }
      aroon = Indicators::Trend.aroon(highs, lows, PARAMS[:aroon])
      {
        dates: rows.map(&:first), close: closes,
        ema9: Indicators::Trend.ema(closes, 9), ema21: Indicators::Trend.ema(closes, 21), ema50: Indicators::Trend.ema(closes, 50),
        hma: Indicators::Trend.hma(closes, PARAMS[:hma]),
        alma: Indicators::Trend.alma(closes, PARAMS[:alma][:length], offset: PARAMS[:alma][:offset], sigma: PARAMS[:alma][:sigma]),
        aroon_up: aroon[:up], aroon_down: aroon[:down]
      }
    end

    # Whether the signal's condition holds on bar i.
    def holds?(series, signal, i)
      s = series
      case signal
      when "ema_9_21" then above?(s[:ema9][i], s[:ema21][i])
      when "ema_21_50" then above?(s[:ema21][i], s[:ema50][i])
      when "ema_stack" then above?(s[:ema9][i], s[:ema21][i]) && above?(s[:ema21][i], s[:ema50][i])
      when "hma_up" then i.positive? && above?(s[:hma][i], s[:hma][i - 1])
      when "alma_cross" then above?(s[:close][i], s[:alma][i])
      when "aroon_cross" then above?(s[:aroon_up][i], s[:aroon_down][i])
      when "aroon_strong" then s[:aroon_up][i] && s[:aroon_up][i] >= STRONG_AROON
      end
    end

    # The bars where the condition starts (false/unknown the bar before, true now).
    def onsets(series, signal)
      (1...series[:close].size).select { |i| holds?(series, signal, i) && known?(series, signal, i - 1) && !holds?(series, signal, i - 1) }
    end

    # The bars where the condition stops (true the bar before, false now).
    def ends(series, signal)
      (1...series[:close].size).select { |i| known?(series, signal, i) && !holds?(series, signal, i) && holds?(series, signal, i - 1) }
    end

    # Each run of the signal inside the data: where it began (the cross), where it
    # ended (or nil if it still holds) and the price change in between.
    def episodes(series, signal)
      closes = series[:close]
      ends_at = ends(series, signal)
      onsets(series, signal).map do |start|
        finish = ends_at.find { _1 > start }
        stop = finish || closes.size - 1
        {
          start_on: series[:dates][start], start_price: closes[start].round(2),
          end_on: finish && series[:dates][finish], end_price: finish && closes[finish].round(2),
          sessions: stop - start, change_pct: ((closes[stop] / closes[start] - 1) * 100).round(2), open: finish.nil?
        }
      end
    end

    # Candles, indicator lines and signal episodes for one stock's chart (completed
    # sessions, last CHART_SESSIONS of them; indicators use the full history first).
    def chart(stock, now: Time.current)
      scope = stock.daily_prices.where("close_price > 0").where(traded_on: (Nepse::MarketHours.today(now) - HISTORY_DAYS)..)
      scope = scope.where(traded_on: ...Nepse::MarketHours.today(now)) if Nepse::MarketHours.sync_window?(now)
      rows = scope.order(:traded_on).pluck(:traded_on, :open_price, :high_price, :low_price, :close_price, :volume)
      return if rows.size < MIN_BARS

      series = compute(rows.map { |d, _o, h, l, c, _v| [ d, h.to_f, l.to_f, c.to_f ] })
      first = [ rows.size - CHART_SESSIONS, 0 ].max
      from = rows[first].first
      line = ->(key) { series[key][first..].map { _1&.round(2) } }
      {
        symbol: stock.symbol, name: stock.name, sector: stock.sector, params: PARAMS, strong_aroon: STRONG_AROON,
        candles: rows[first..].map { |d, o, h, l, c, v| { traded_on: d, open: (o.to_f.positive? ? o : c).to_f, high: [ h.to_f, c.to_f ].max, low: (l.to_f.positive? ? l : c).to_f, close: c.to_f, volume: v.to_i } },
        lines: %i[ema9 ema21 ema50 hma alma aroon_up aroon_down].to_h { [ _1, line.(_1) ] },
        episodes: SIGNALS.to_h { |signal| [ signal, episodes(series, signal).select { _1[:start_on] >= from } ] },
        signals: SIGNALS.to_h { [ _1, latest_age(series, _1) ] }
      }
    end

    # Sessions since the current run of the condition began, or nil if it doesn't hold
    # now. A run that has held since the indicator's first value counts from there.
    def latest_age(series, signal)
      last = series[:close].size - 1
      return unless holds?(series, signal, last)

      start = last
      start -= 1 while start.positive? && holds?(series, signal, start - 1)
      last - start
    end

    def known?(series, signal, i)
      keys = { "ema_9_21" => %i[ema9 ema21], "ema_21_50" => %i[ema21 ema50], "ema_stack" => %i[ema9 ema21 ema50],
               "hma_up" => %i[hma], "alma_cross" => %i[alma], "aroon_cross" => %i[aroon_up aroon_down], "aroon_strong" => %i[aroon_up] }.fetch(signal)
      i >= (signal == "hma_up" ? 1 : 0) && keys.all? { series[_1][i] && (signal != "hma_up" || series[:hma][i - 1]) }
    end

    def above?(a, b) = a && b && a > b

    def values(series)
      %i[ema9 ema21 ema50 hma alma aroon_up aroon_down].to_h { [ _1, series[_1].last&.round(2) ] }
    end

    # Readiness, board flag and liquidity from each stock's latest snapshot.
    def latest_snapshots
      latest = StockSetupSnapshot.maximum(:traded_on)
      return {} unless latest

      StockSetupSnapshot.where(traded_on: latest).pluck(:stock_id, :readiness_score, :in_buy_zone, :guards, :avg_turnover)
                        .to_h { |id, readiness, board, guards, turnover| [ id, { readiness: readiness, in_buy_zone: board, guards: guards, avg_turnover: turnover&.to_f } ] }
    end
  end
end
