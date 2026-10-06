# Sends a position sell-rule alert to the user's Telegram chat.
class TelegramPositionAlertJob < ApplicationJob
  queue_as :default

  def perform(alert_id)
    return unless Telegram::Client.configured?

    alert = PositionAlert.includes(:user, position: :stock).find_by(id: alert_id)
    alert && Telegram::Notifier.position_alert(alert)
  end
end
