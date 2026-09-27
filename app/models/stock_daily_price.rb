class StockDailyPrice < ApplicationRecord
  belongs_to :stock

  validates :traded_on, presence: true
  validates :stock_id, uniqueness: { scope: :traded_on, message: "already has a daily price for this date" }
  validates :open_price, :high_price, :low_price, :close_price, numericality: { greater_than_or_equal_to: 0 }
  validates :volume, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(traded_on: :asc) }
  scope :reverse_chronological, -> { order(traded_on: :desc) }
  scope :between_dates, ->(start_date, end_date) { where(traded_on: start_date..end_date) }
  scope :recent, ->(limit = 30) { reverse_chronological.limit(limit) }

  before_save :calculate_changes

  private

  def calculate_changes
    return if previous_close.nil? || previous_close.zero? || close_price.nil?

    self.change_amount = close_price - previous_close
    self.change_percent = ((change_amount / previous_close) * 100).round(2)
  end
end
