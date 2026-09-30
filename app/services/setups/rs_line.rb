module Setups
  # Relative-strength line: the stock's close divided by the NEPSE index on the same
  # session, scaled so the first point shown is 100. Rising means the stock is doing
  # better than the market. A new high is an RS value above every one of the prior
  # LOOKBACK sessions (all stored history when shorter, but at least MIN_WINDOW).
  # When RS makes a new high while price is still below its own high over the same
  # window, RS is leading price, a common sign of an emerging leader.
  module RsLine
    LOOKBACK = 252
    MIN_WINDOW = 20
    CHANGE_SESSIONS = [ 20, 60 ].freeze

    module_function

    def call(stock, sessions: 200)
      rows = series(stock)
      return empty if rows.size < 2

      points = rows.each_with_index.map do |(traded_on, close, rs), i|
        window = rows[[ 0, i - LOOKBACK ].max...i]
        new_high = window.size >= MIN_WINDOW && rs > window.map(&:last).max
        { traded_on: traded_on, rs: rs, new_high: new_high, leads_price: new_high && close < window.map { _2 }.max }
      end

      shown = points.last(sessions)
      base = shown.first[:rs]
      last_high = points.reverse.find { _1[:new_high] }
      {
        points: shown.map do |point|
          { traded_on: point[:traded_on].iso8601, value: (point[:rs] / base * 100).round(2), new_high: point[:new_high], leads_price: point[:leads_price] }
        end,
        change: CHANGE_SESSIONS.to_h { |n| [ n, change(points, n) ] },
        last_new_high_on: last_high&.dig(:traded_on)&.iso8601,
        last_new_high_leads_price: last_high ? last_high[:leads_price] : false
      }
    end

    # [traded_on, close, close / NEPSE] for sessions with both a close and an index value.
    def series(stock)
      nepse = MarketIndexHistory.joins(:market_index).where(market_indices: { symbol: "NEPSE" }).pluck(:traded_on, :index_value).to_h
      stock.daily_prices.order(:traded_on).pluck(:traded_on, :close_price).filter_map do |traded_on, close|
        index = nepse[traded_on].to_f
        [ traded_on, close.to_f, close.to_f / index ] if index.positive? && close.to_f.positive?
      end
    end

    # % change of the RS line over the last n sessions: how far the stock beat (+) or lagged (-) NEPSE.
    def change(points, sessions)
      return if points.size <= sessions

      ((points.last[:rs] / points[-1 - sessions][:rs] - 1) * 100).round(2)
    end

    def empty = { points: [], change: CHANGE_SESSIONS.to_h { [ _1, nil ] }, last_new_high_on: nil, last_new_high_leads_price: false }
  end
end
