# One automated paper trade (PaperTrading::Engine): no real order is placed.
class PaperTrade < ApplicationRecord
  STATUSES = %w[pending open closed].freeze
  TRIGGERS = %w[watchlist_entered_zone watchlist_breakout board_new].freeze

  belongs_to :user
  belongs_to :stock
  has_many :events, class_name: "PaperTradeEvent", dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  validates :trigger, inclusion: { in: TRIGGERS }

  scope :active, -> { where(status: %w[pending open]) }
  scope :open, -> { where(status: "open") }

  # Duck-typed like Position for Positions::Monitor's close rules.
  def opened_on = entry_at&.in_time_zone(Nepse::MarketHours::TIME_ZONE)&.to_date
  def last_price = stock.last_price.to_f
  def average_price = entry_price.to_f

  def r_multiple
    risk = entry_price.to_f - initial_stop_price.to_f
    risk.positive? && entry_price ? ((last_price - entry_price.to_f) / risk).round(2) : nil
  end

  # NEPSE settles in T+2: shares can be sold from the second trading day after the buy.
  def sellable_on
    day = opened_on or return
    2.times { day = Nepse::MarketHours.next_trading_day(day) }
    day
  end

  def cost_basis = (entry_price.to_f * quantity + buy_costs.to_f).round(2)
  def unrealized_pnl = (Nepse::Costs.net_proceeds(last_price, quantity) - cost_basis).round(2)
end
