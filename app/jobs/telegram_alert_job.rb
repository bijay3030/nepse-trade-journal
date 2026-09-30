# Sends a watchlist zone-entry alert to the user's Telegram chat.
class TelegramAlertJob < ApplicationJob
  queue_as :default

  def perform(alert_id)
    return unless Telegram::Client.configured?

    alert = WatchlistAlert.includes(:user, watchlist_item: :stock).find_by(id: alert_id)
    alert && Telegram::Notifier.watchlist_alert(alert)
  end
end
