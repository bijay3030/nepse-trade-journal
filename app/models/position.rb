# A stock the user holds (or held). Quantity and average price come from its fills;
# stop and target are the user's plan, defaulting to the watchlist setup's levels.
class Position < ApplicationRecord
  STATUSES = %w[open closed].freeze
  # The stop defaults to the setup's invalidation, but never more than this far below entry.
  MAX_STOP_PCT = 8.0

  belongs_to :user
  belongs_to :stock
  belongs_to :watchlist_item, optional: true
  has_many :alerts, class_name: "PositionAlert", dependent: :delete_all
  has_many :fills, -> { order(:traded_on, :id) }, class_name: "PositionFill", dependent: :delete_all, inverse_of: :position

  validates :status, inclusion: { in: STATUSES }
  validates :stop_price, :initial_stop_price, numericality: { greater_than: 0 }
  validates :target_price, numericality: { greater_than: 0 }, allow_nil: true

  scope :open, -> { where(status: "open") }
  scope :closed, -> { where(status: "closed") }

  # The setup's stop, raised to MAX_STOP_PCT below entry when it's further away.
  def self.default_stop(entry, setup_stop)
    floor = (entry.to_f * (1 - MAX_STOP_PCT / 100)).round(2)
    setup_stop.to_f.positive? ? [ setup_stop.to_f, floor ].max : floor
  end

  def open? = status == "open"

  def buys = fills.select(&:buy?)
  def sells = fills.reject(&:buy?)

  def quantity = buys.sum(&:quantity) - sells.sum(&:quantity)

  # Weighted average buy price per share, before fees.
  def average_price
    bought = buys.sum(&:quantity)
    return 0.0 if bought.zero?

    (buys.sum { _1.price.to_f * _1.quantity } / bought).round(2)
  end

  # What the open shares cost, including each buy's commission and SEBON fee.
  def cost_basis
    bought = buys.sum(&:quantity)
    return 0.0 if bought.zero?

    total = buys.sum { |fill| amount = fill.price.to_f * fill.quantity; amount + Nepse::Costs.buy_costs(amount) }
    (total / bought * quantity).round(2)
  end

  # Selling everything at the last price, after sell costs (before capital gains tax).
  def net_pnl_if_sold = quantity.positive? ? (Nepse::Costs.net_proceeds(last_price, quantity) - cost_basis).round(2) : 0.0

  def break_even_price = Nepse::Costs.break_even_price(cost_basis, quantity)

  def opened_on = buys.map(&:traded_on).min
  def last_buy_on = buys.map(&:traded_on).max
  def last_price = stock.last_price.to_f

  def unrealized_pnl = ((last_price - average_price) * quantity).round(2)

  def unrealized_pct
    average_price.positive? ? ((last_price / average_price - 1) * 100).round(2) : nil
  end

  # R: the move in units of the risk taken at entry (average price to the first stop).
  def r_multiple
    risk = average_price - initial_stop_price.to_f
    risk.positive? ? ((last_price - average_price) / risk).round(2) : nil
  end

  # What's lost if the current stop is hit, after buy and sell costs; zero once selling
  # at the stop would no longer lose money.
  def open_risk
    return 0.0 unless quantity.positive?

    [ cost_basis - Nepse::Costs.net_proceeds(stop_price, quantity), 0 ].max.round(2)
  end

  def days_held(today = Nepse::MarketHours.today) = opened_on ? (today - opened_on).to_i : 0

  # NEPSE settles T+2: shares bought on a day can be sold two trading days later.
  # Weekends follow NEPSE_TRADING_DAYS; public holidays aren't known, so it can be later.
  def sellable_on
    day = last_buy_on
    return unless day

    2.times { day = Nepse::MarketHours.next_trading_day(day) }
    day
  end
end
