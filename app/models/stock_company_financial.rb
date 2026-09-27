class StockCompanyFinancial < ApplicationRecord
  belongs_to :stock

  VALID_QUARTERS = %w[Q1 Q2 Q3 Q4 Annual].freeze

  validates :fiscal_year, presence: true
  validates :quarter, presence: true, inclusion: { in: VALID_QUARTERS }
  validates :stock_id, uniqueness: { scope: [:fiscal_year, :quarter], message: "already has financial records for this fiscal year and quarter" }
  validates :eps, :book_value, :pe_ratio, :pb_ratio, :roe, numericality: true, allow_nil: true

  scope :recent_reports, -> { order(reported_on: :desc, fiscal_year: :desc, quarter: :desc) }
  scope :annual, -> { where(quarter: "Annual") }
  scope :quarterly, -> { where.not(quarter: "Annual") }
end
