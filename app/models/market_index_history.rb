class MarketIndexHistory < ApplicationRecord
  belongs_to :market_index

  validates :traded_on, presence: true
  validates :market_index_id, uniqueness: { scope: :traded_on, message: "already has index value recorded for this date" }
  validates :index_value, numericality: { greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(traded_on: :asc) }
  scope :reverse_chronological, -> { order(traded_on: :desc) }
end
