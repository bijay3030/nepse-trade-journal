# A stock the user holds (or held). Quantity and average price come from its fills;
# stop and target are the user's plan, defaulting to the watchlist setup's levels.
class Position < ApplicationRecord
  STATUSES = %w[open closed].freeze
  PLAN_FOLLOWED = %w[yes partly no].freeze
  REVIEW_TAGS = %w[chased_entry moved_stop_down sold_too_early held_past_stop oversized ignored_market].freeze
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
  validates :review_plan_followed, inclusion: { in: PLAN_FOLLOWED }, allow_nil: true
  validate :review_tags_known

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

  # Sells matched to buys first-in, first-out (Positions::Ledger).
  def ledger = @ledger ||= Positions::Ledger.new(fills)

  def reload(*)
    @ledger = nil
    super
  end

  # What the open shares cost, including each buy's commission and SEBON fee (FIFO:
  # after a partial sell, the shares left are the latest buys).
  def cost_basis = ledger.open_cost

  # Realized P&L of the sells so far: proceeds, cost, gain after costs, CGT and net.
  def realized = ledger.realized

  # Shares that have settled (T+2) by `day` and haven't been sold yet.
  def settled_quantity(day = Nepse::MarketHours.today)
    settled = buys.select { settles_on(_1.traded_on) <= day }.sum(&:quantity)
    [ settled - sells.select { _1.traded_on <= day }.sum(&:quantity), 0 ].max
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

  def days_held(today = Nepse::MarketHours.today) = opened_on ? ((closed_on || today) - opened_on).to_i : 0

  # NEPSE settles T+2: shares bought on a day can be sold two trading days later.
  # Weekends follow NEPSE_TRADING_DAYS; public holidays aren't known, so it can be later.
  def sellable_on = last_buy_on && settles_on(last_buy_on)

  def settles_on(day)
    2.times { day = Nepse::MarketHours.next_trading_day(day) }
    day
  end

  # Closed trades: the average sell price, R on that, and the worst / best prices
  # while held (MAE / MFE) from daily lows and highs, in % of the average buy and in R.
  def average_sell_price
    sold = sells.sum(&:quantity)
    sold.positive? ? (sells.sum { _1.price.to_f * _1.quantity } / sold).round(2) : nil
  end

  def closed_r_multiple
    risk = average_price - initial_stop_price.to_f
    average_sell_price && risk.positive? ? ((average_sell_price - average_price) / risk).round(2) : nil
  end

  def excursions
    return {} unless opened_on && average_price.positive?

    range = stock.daily_prices.where(traded_on: opened_on..(closed_on || Nepse::MarketHours.today)).pick(Arel.sql("MIN(low_price), MAX(high_price)"))
    low, high = range&.map(&:to_f)
    return {} unless low&.positive? && high&.positive?

    risk = average_price - initial_stop_price.to_f
    { mae_pct: ((low / average_price - 1) * 100).round(2), mfe_pct: ((high / average_price - 1) * 100).round(2),
      mae_r: risk.positive? ? ((low - average_price) / risk).round(2) : nil, mfe_r: risk.positive? ? ((high - average_price) / risk).round(2) : nil }
  end

  private

  def review_tags_known
    unknown = Array(review_tags) - REVIEW_TAGS
    errors.add(:review_tags, "has unknown tags: #{unknown.join(', ')}") if unknown.any?
  end
end
