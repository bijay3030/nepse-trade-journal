# A sell-rule alert for an open position. See Positions::Monitor.
class PositionAlert < ApplicationRecord
  # Checked against live prices during the session.
  LIVE_KINDS = %w[stop_hit target_reached one_r profit_zone].freeze
  # Checked on the day's close.
  CLOSE_KINDS = %w[fifty_day_break climax_run time_stop].freeze
  KINDS = (LIVE_KINDS + CLOSE_KINDS).freeze

  belongs_to :user
  belongs_to :position

  validates :kind, inclusion: { in: KINDS }
  validates :message, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  after_create_commit :queue_telegram

  private

  def queue_telegram
    TelegramPositionAlertJob.perform_later(id) if Telegram::Client.configured? && user.telegram_chat_id.present?
  end
end
