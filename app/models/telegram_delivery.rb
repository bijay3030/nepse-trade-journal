# A Telegram message sent about a stock; see Telegram::Notifier.
class TelegramDelivery < ApplicationRecord
  KINDS = %w[watchlist_zone watchlist_early entry_zone_board].freeze

  belongs_to :user
  belongs_to :stock

  validates :kind, inclusion: { in: KINDS }

  # Records the delivery and returns true, or false when one was already sent that session.
  def self.claim(user:, stock:, kind:, traded_on:)
    create!(user: user, stock: stock, kind: kind, traded_on: traded_on)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
