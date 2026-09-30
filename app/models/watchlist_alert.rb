class WatchlistAlert < ApplicationRecord
  INTRADAY_KINDS = %w[entered_zone breakout_confirmed breakout_low_volume extended invalidated].freeze
  CLOSE_KINDS = %w[close_confirmed close_unconfirmed close_failed close_in_zone].freeze
  KINDS = (INTRADAY_KINDS + CLOSE_KINDS).freeze

  belongs_to :user
  belongs_to :watchlist_item

  validates :kind, inclusion: { in: KINDS }
  validates :message, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
