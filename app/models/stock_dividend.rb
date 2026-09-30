class StockDividend < ApplicationRecord
  belongs_to :stock

  validates :fiscal_year, presence: true, uniqueness: { scope: :stock_id }
  validates :source, inclusion: { in: %w[chukul merolagani] }

  scope :latest_first, -> { order(fiscal_year: :desc) }
end
