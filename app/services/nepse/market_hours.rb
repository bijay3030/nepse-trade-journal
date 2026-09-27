module Nepse
  # NEPSE trades 11:00 to 15:00 Nepal time. Trading days moved from Sunday-Thursday
  # to Monday-Friday in 2026 (visible in the daily price history), so the days are
  # configurable with NEPSE_TRADING_DAYS (0 = Sunday ... 6 = Saturday).
  # Public holidays are not modelled yet.
  module MarketHours
    TIME_ZONE = "Asia/Kathmandu".freeze
    DEFAULT_TRADING_WDAYS = [ 1, 2, 3, 4, 5 ].freeze
    OPEN_MINUTE = 11 * 60
    CLOSE_MINUTE = 15 * 60
    # Keep syncing briefly after the close so the final prices are captured.
    CLOSING_GRACE_MINUTES = 15

    module_function

    def trading_wdays
      configured = ENV["NEPSE_TRADING_DAYS"].to_s.split(",").map(&:strip).select { _1.match?(/\A[0-6]\z/) }.map(&:to_i)
      configured.any? ? configured : DEFAULT_TRADING_WDAYS
    end

    def open?(time = Time.current)
      within?(time, CLOSE_MINUTE)
    end

    def sync_window?(time = Time.current)
      within?(time, CLOSE_MINUTE + CLOSING_GRACE_MINUTES)
    end

    def within?(time, end_minute)
      local = time.in_time_zone(TIME_ZONE)
      minute = local.hour * 60 + local.min
      trading_wdays.include?(local.wday) && minute >= OPEN_MINUTE && minute < end_minute
    end
    private_class_method :within?
  end
end
