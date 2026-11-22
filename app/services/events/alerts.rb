module Events
  # Telegram messages about market events (after each Events::Sync), one message per user:
  #
  #   your stocks     every new event for stocks on the user's watchlist, in an open
  #                   position, on their saved scanner filter's radar, or on the Strategy
  #                   Lab's watch list
  #   market-wide     new events for any other company only when they matter most:
  #                   bonus and rights announcements, regulatory action, mergers
  #   book closes     a reminder, once, for a bonus, cash dividend or rights book close
  #                   within REMINDER_DAYS (any company: the price adjusts that day)
  #
  # "New" means published within FRESH_DAYS and not sent to the user before
  # (market_event_deliveries), so a first run doesn't send a backlog. Rule output, not advice.
  module Alerts
    FRESH_DAYS = 2
    REMINDER_DAYS = 5
    LIMIT = 12
    MARKET_KINDS = %w[bonus rights regulatory merger promoter_lockin].freeze
    BOOK_CLOSE_KINDS = %w[bonus cash_dividend rights].freeze

    module_function

    def deliver(today: Nepse::MarketHours.today, client: Telegram::Client.new)
      users = User.where.not(telegram_chat_id: nil).where(telegram_event_alerts: true)
      return {} unless users.exists?

      fresh = MarketEvent.includes(:stock).where(published_on: (today - FRESH_DAYS)..today).to_a
      upcoming = MarketEvent.includes(:stock).where(kind: BOOK_CLOSE_KINDS, event_on: today..(today + REMINDER_DAYS)).to_a
      lab = lab_stock_ids
      users.find_each.to_h do |user|
        mine = my_stock_ids(user) | lab
        sent = MarketEventDelivery.where(user: user).pluck(:market_event_id, :reason).to_set
        own = fresh.select { _1.stock_id && mine.include?(_1.stock_id) && !sent.include?([ _1.id, "new" ]) }
        market = fresh.select { !own.include?(_1) && _1.important && MARKET_KINDS.include?(_1.kind) && !sent.include?([ _1.id, "new" ]) }
        closes = upcoming.select { !sent.include?([ _1.id, "book_close" ]) && (mine.include?(_1.stock_id) || _1.important || _1.kind == "rights") }
        next [ user.id, :none ] if own.empty? && market.empty? && closes.empty?

        text = Telegram::Messages.market_events(own: own, market: market, book_closes: closes, today: today)
        next [ user.id, :failed ] unless Telegram::Notifier.deliver(user, text, client)

        rows = (own + market).map { { user_id: user.id, market_event_id: _1.id, reason: "new", created_at: Time.current } } +
               closes.map { { user_id: user.id, market_event_id: _1.id, reason: "book_close", created_at: Time.current } }
        MarketEventDelivery.insert_all(rows, unique_by: :index_market_event_deliveries_once) if rows.any?
        [ user.id, :sent ]
      end
    end

    # Watchlist, open positions and the saved scanner filter's radar.
    def my_stock_ids(user)
      ids = user.watchlist_items.tracked.pluck(:stock_id) + Position.where(user: user).open.pluck(:stock_id)
      signals = user.scanner_alert_signals & Scans::Crossovers::SIGNALS
      if signals.any?
        radar = Scans::Cache.scan[:rows].select { Scans::EntryAlerts.on_radar?(_1, signals, volume: user.scanner_alert_volume) }.map { _1[:symbol] }
        ids += Stock.where(symbol: radar).pluck(:id)
      end
      ids.to_set
    end

    def lab_stock_ids
      report = Lab::Cache.report
      symbols = report[:candidates].map { _1[:symbol] } + report[:qualifying].values.flatten.map { _1[:symbol] }
      Stock.where(symbol: symbols).pluck(:id).to_set
    rescue StandardError => e
      Rails.logger.warn("Events::Alerts: Strategy Lab list unavailable: #{e.message}")
      Set.new
    end
  end
end
