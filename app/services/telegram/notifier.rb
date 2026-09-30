module Telegram
  # Sends entry-zone messages to linked users, at most one per stock, kind and
  # session (TelegramDelivery). A chat that blocked the bot is unlinked.
  module Notifier
    ZONE_ALERT_KINDS = %w[entered_zone breakout_confirmed breakout_low_volume].freeze

    module_function

    # A watchlist alert: sent when it's a zone entry and the user wants these.
    def watchlist_alert(alert, client: Client.new)
      user = alert.user
      return :skipped unless ZONE_ALERT_KINDS.include?(alert.kind) && user.telegram_chat_id.present? && user.telegram_watchlist_alerts

      stock = alert.watchlist_item.stock
      session = alert.created_at.in_time_zone("Asia/Kathmandu").to_date
      return :duplicate unless TelegramDelivery.claim(user: user, stock: stock, kind: "watchlist_zone", traded_on: session)

      deliver(user, Messages.watchlist_alert(alert), client) ? :sent : :failed
    end

    # After the nightly snapshot: one message per user with the stocks new on the board.
    def entry_zone_board(traded_on = StockSetupSnapshot.maximum(:traded_on), client: Client.new)
      return {} unless traded_on

      joined = StockSetupSnapshot.joined_board(traded_on).includes(:stock).order(readiness_score: :desc).to_a
      return {} if joined.empty?

      User.where.not(telegram_chat_id: nil).where(telegram_board_alerts: true).find_each.to_h do |user|
        fresh = joined.select { TelegramDelivery.claim(user: user, stock: _1.stock, kind: "entry_zone_board", traded_on: traded_on) }
        result = fresh.empty? ? :duplicate : (deliver(user, Messages.entry_zone_board(fresh, traded_on), client) ? :sent : :failed)
        [ user.id, result ]
      end
    end

    def deliver(user, text, client)
      client.send_message(user.telegram_chat_id, text)
      true
    rescue Error => e
      Rails.logger.warn("Telegram message to user #{user.id} failed: #{e.message}")
      Linker.unlink!(user) if e.chat_unreachable?
      false
    end
  end
end
