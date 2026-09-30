class WatchlistAlert < ApplicationRecord
  INTRADAY_KINDS = %w[entered_zone breakout_confirmed breakout_low_volume extended invalidated].freeze
  CLOSE_KINDS = %w[close_confirmed close_unconfirmed close_failed close_in_zone].freeze
  CORPORATE_KINDS = %w[book_close_soon levels_adjusted].freeze
  KINDS = (INTRADAY_KINDS + CLOSE_KINDS + CORPORATE_KINDS).freeze

  belongs_to :user
  belongs_to :watchlist_item

  validates :kind, inclusion: { in: KINDS }
  validates :message, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
