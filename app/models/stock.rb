class Stock < ApplicationRecord
  has_many :trade_plans, dependent: :restrict_with_exception
  has_many :holdings, dependent: :restrict_with_exception
  has_many :daily_prices, class_name: "StockDailyPrice", dependent: :destroy
  has_many :daily_indicators, class_name: "StockDailyIndicator", dependent: :destroy
  has_many :company_financials, class_name: "StockCompanyFinancial", dependent: :destroy
  has_many :watchlist_items, dependent: :destroy

  scope :active, -> { where(is_active: true) }
  scope :by_sector, ->(sector) { where(sector: sector) }
  scope :by_security_type, ->(type) { where(security_type: type) }

  validates :symbol, presence: true, uniqueness: true
  validates :name, :sector, presence: true

  before_validation :normalize_sector

  SECTOR_ALIASES = {
    "Hydro Power" => "Hydropower",
    "Banking" => "Commercial Banks",
    "Insurance" => "Non Life Insurance"
  }.freeze
  QUARTER_PRIORITY = {
    "Q1" => 1,
    "Q2" => 2,
    "Q3" => 3,
    "Q4" => 4,
    "Annual" => 5
  }.freeze

  def latest_financial
    company_financials.max_by do |financial|
      [
        financial.reported_on || Date.new(0),
        financial.fiscal_year.to_s,
        QUARTER_PRIORITY.fetch(financial.quarter, 0),
        financial.id.to_i
      ]
    end
  end

  def current_eps
    latest_financial&.eps&.to_f || 0.0
  end

  def current_pe_ratio
    persisted_ratio = latest_financial&.pe_ratio.to_f
    return persisted_ratio if persisted_ratio.positive?

    return 0.0 if current_eps.zero?

    (last_price.to_f / current_eps).round(2)
  end

  def current_book_value
    latest_financial&.book_value&.to_f || 0.0
  end

  def current_pb_ratio
    persisted_ratio = latest_financial&.pb_ratio.to_f
    return persisted_ratio if persisted_ratio.positive?

    return 0.0 if current_book_value.zero?

    (last_price.to_f / current_book_value).round(2)
  end

  def recalculate_market_cap!
    return if listed_shares.nil? || listed_shares.zero?
    return unless last_price.to_f.positive?

    calculated_cap = (listed_shares * last_price).to_f
    update(market_cap: calculated_cap)
  end

  def previous_close_before(date)
    daily_prices.where("traded_on < ?", date).order(traded_on: :desc).pick(:close_price)&.to_f
  end

  # Applies a quote from NepsePriceService. Fields the source did not provide are
  # left untouched instead of being overwritten with zeros.
  def apply_live_quote!(price_data, traded_on: Date.current)
    last_price = price_data[:last_price].to_f
    return false unless last_price.positive?

    previous_close = price_data[:previous_close] || previous_close_before(traded_on)
    change_percent = price_data[:change_percent]
    if change_percent.nil? && previous_close.to_f.positive?
      change_percent = (((last_price - previous_close) / previous_close) * 100).round(2)
    end

    updates = { last_price: last_price, last_updated: Time.current }
    updates[:change_percent] = change_percent unless change_percent.nil?
    updates[:volume] = price_data[:volume] unless price_data[:volume].nil?
    update!(updates)
    recalculate_market_cap!
    true
  end

  def quote_payload
    {
      symbol: symbol,
      last_price: last_price.to_f,
      change_percent: change_percent.to_f,
      volume: volume.to_i,
      last_updated: last_updated
    }
  end

  def price_payload
    {
      id: id,
      symbol: symbol,
      name: name,
      sector: sector,
      security_type: security_type,
      last_price: last_price.to_f,
      change_percent: change_percent.to_f,
      volume: volume.to_i,
      listed_shares: listed_shares.to_i,
      market_cap: market_cap.to_f,
      high_52w: high_52w.to_f,
      low_52w: low_52w.to_f,
      eps: current_eps,
      pe_ratio: current_pe_ratio,
      book_value: current_book_value,
      pb_ratio: current_pb_ratio,
      last_updated: last_updated
    }
  end

  private

  def normalize_sector
    return if sector.blank?
    self.sector = SECTOR_ALIASES[sector] || sector
  end
end
