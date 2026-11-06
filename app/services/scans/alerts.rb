module Scans
  # Telegram messages for each user's saved Indicator Scanner filter: after the close,
  # the liquid stocks that newly match every chosen signal on the latest session. A
  # combination newly matches when all its signals hold and the last of them switched
  # on that session (so it didn't match the session before); a stock that keeps
  # matching isn't repeated. Each stock is sent at most once per user and session.
  module Alerts
    LIMIT = 15

    module_function

    def new_matches(scan, signals)
      return [] if signals.empty?

      scan[:rows].select do |row|
        ages = signals.map { row[:signals][_1] }
        ages.none?(&:nil?) && ages.min.zero? && !Array(row[:guards]).include?("thin_volume")
      end
    end

    # { user_id => :sent / :duplicate / :failed / :none } for linked users with a filter.
    def deliver(scan: Cache.crossovers, today: Nepse::MarketHours.today, client: Telegram::Client.new)
      return {} unless scan[:as_of] == today

      User.where.not(telegram_chat_id: nil).where("jsonb_array_length(scanner_alert_signals) > 0").find_each.to_h do |user|
        signals = user.scanner_alert_signals & Crossovers::SIGNALS
        matches = new_matches(scan, signals)
        next [ user.id, :none ] if matches.empty?

        stocks = Stock.where(symbol: matches.map { _1[:symbol] }).index_by(&:symbol)
        fresh = matches.select { (stock = stocks[_1[:symbol]]) && TelegramDelivery.claim(user: user, stock: stock, kind: "scanner_alert", traded_on: today) }
        next [ user.id, :duplicate ] if fresh.empty?

        text = Telegram::Messages.scanner_alert(fresh, signals, scan)
        [ user.id, Telegram::Notifier.deliver(user, text, client) ? :sent : :failed ]
      end
    end
  end
end
