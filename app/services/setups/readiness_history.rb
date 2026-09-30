module Setups
  # Readiness over the last snapshot sessions, oldest first, for sparklines.
  module ReadinessHistory
    SESSIONS = 60

    module_function

    def for_stock(stock, sessions: SESSIONS) = for_stocks([ stock.id ], sessions: sessions).fetch(stock.id, [])

    def for_stocks(stock_ids, sessions: SESSIONS)
      dates = StockSetupSnapshot.distinct.order(traded_on: :desc).limit(sessions).pluck(:traded_on)
      return {} if dates.empty? || stock_ids.empty?

      StockSetupSnapshot.where(stock_id: stock_ids, traded_on: dates).order(:traded_on)
                        .pluck(:stock_id, :traded_on, :readiness_score, :zone_state, :in_buy_zone)
                        .group_by(&:first)
                        .transform_values do |rows|
                          rows.map { |_, traded_on, score, zone, in_buy_zone| { traded_on: traded_on.iso8601, score: score, zone_state: zone, in_buy_zone: in_buy_zone } }
                        end
    end
  end
end
