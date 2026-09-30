module Setups
  # Tradability guards that keep a stock off "Entry zone now" even when its chart
  # qualifies. They describe whether an order could be filled sensibly, not the setup.
  #
  #   thin_volume    average daily turnover over the last 20 sessions below NPR 2M
  #                  (NEPSE_MIN_TURNOVER). Sessions the stock didn't trade count as 0.
  #   upper_circuit  closed +9.5% or more, at or near the +10% daily limit: sellers are
  #                  scarce and the next open often gaps; wait for another session.
  #   lower_circuit  closed -9.5% or less: buyers are scarce and a stop may not fill.
  module Guards
    WINDOW = 20
    MIN_TURNOVER = ENV.fetch("NEPSE_MIN_TURNOVER", 2_000_000).to_f
    DAILY_LIMIT_PCT = 10.0
    CIRCUIT_NEAR_PCT = 9.5
    ALL = %w[thin_volume upper_circuit lower_circuit].freeze

    module_function

    def call(avg_turnover:, change_pct:)
      guards = []
      guards << "thin_volume" if avg_turnover && avg_turnover < MIN_TURNOVER
      guards << "upper_circuit" if change_pct && change_pct >= CIRCUIT_NEAR_PCT
      guards << "lower_circuit" if change_pct && change_pct <= -CIRCUIT_NEAR_PCT
      guards
    end

    # Average turnover over the market sessions given (newest first); nil without sessions.
    def avg_turnover(prices, sessions)
      return if sessions.empty?

      window = sessions.first(WINDOW)
      traded = prices.select { window.include?(_1.traded_on) }
      traded.sum { turnover(_1) } / window.size
    end

    # Close-to-close change for the session, from stored closes (point in time).
    def change_pct(prices, traded_on)
      series = prices.select { _1.traded_on <= traded_on }.sort_by(&:traded_on).last(2)
      return if series.size < 2 || series.first.traded_on == traded_on

      previous, current = series.map { _1.close_price.to_f }
      return unless previous.positive?

      ((current / previous - 1) * 100).round(2)
    end

    # Some sources leave turnover empty; volume x close is close enough then.
    def turnover(price)
      value = price.turnover.to_f
      value.positive? ? value : price.volume.to_i * price.close_price.to_f
    end
  end
end
