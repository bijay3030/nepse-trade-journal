module Nepse
  # NEPSE trades Sunday to Thursday, 11:00 to 15:00 Nepal time. Public holidays
  # are not modelled yet.
  module MarketHours
    TIME_ZONE = "Asia/Kathmandu".freeze
    TRADING_WDAYS = (0..4).freeze
    OPEN_MINUTE = 11 * 60
    CLOSE_MINUTE = 15 * 60
    # Keep syncing briefly after the close so the final prices are captured.
    CLOSING_GRACE_MINUTES = 15

    module_function

    def open?(time = Time.current)
      within?(time, CLOSE_MINUTE)
    end

    def sync_window?(time = Time.current)
      within?(time, CLOSE_MINUTE + CLOSING_GRACE_MINUTES)
    end

    def within?(time, end_minute)
      local = time.in_time_zone(TIME_ZONE)
      minute = local.hour * 60 + local.min
      TRADING_WDAYS.cover?(local.wday) && minute >= OPEN_MINUTE && minute < end_minute
    end
    private_class_method :within?
  end
end
