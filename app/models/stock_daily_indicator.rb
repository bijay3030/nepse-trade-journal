class StockDailyIndicator < ApplicationRecord
  belongs_to :stock
  belongs_to :stock_daily_price, optional: true

  validates :traded_on, presence: true
  validates :stock_id, uniqueness: { scope: :traded_on, message: "already has an indicator record for this date" }

  scope :chronological, -> { order(traded_on: :asc) }
  scope :reverse_chronological, -> { order(traded_on: :desc) }
  scope :between_dates, ->(start_date, end_date) { where(traded_on: start_date..end_date) }

  def trend_summary
    {
      sma_20: sma_20&.to_f,
      sma_50: sma_50&.to_f,
      sma_150: sma_150&.to_f,
      sma_200: sma_200&.to_f,
      ema_20: ema_20&.to_f,
      ema_50: ema_50&.to_f
    }
  end

  def volatility_summary
    {
      atr_14: atr_14&.to_f,
      atr_percent: atr_percent&.to_f
    }
  end

  def volume_summary
    {
      avg_volume_10: avg_volume_10,
      avg_volume_20: avg_volume_20,
      avg_volume_50: avg_volume_50,
      rvol: rvol&.to_f
    }
  end

  def price_position_summary
    {
      high_52w: high_52w&.to_f,
      low_52w: low_52w&.to_f,
      pct_below_high_52w: pct_below_high_52w&.to_f,
      pct_above_low_52w: pct_above_low_52w&.to_f
    }
  end

  def momentum_summary
    {
      change_pct_1d: change_pct_1d&.to_f,
      change_pct_20d: change_pct_20d&.to_f,
      change_pct_50d: change_pct_50d&.to_f
    }
  end
end
