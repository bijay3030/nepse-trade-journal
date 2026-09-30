# A stock the user is tracking toward an entry, with its entry zone and the
# level at which the setup is considered failed.
class WatchlistItem < ApplicationRecord
  SETUP_TYPES = Setups::Types::ALL
  STATUSES = %w[watching in_zone extended invalidated planned archived].freeze
  PRICE_STATES = %w[below_zone in_zone extended invalidated].freeze
  # Statuses the price no longer changes: the user has acted, or the setup failed.
  STICKY_STATUSES = %w[invalidated planned archived].freeze

  belongs_to :user
  belongs_to :stock
  belongs_to :trade_plan, optional: true
  has_many :alerts, class_name: "WatchlistAlert", dependent: :delete_all

  validates :setup_type, inclusion: { in: SETUP_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :price_state, inclusion: { in: PRICE_STATES }, allow_nil: true
  validates :last_close_state, inclusion: { in: %w[confirmed unconfirmed failed held_zone in_zone below_zone above_zone invalidated] }, allow_nil: true
  validates :entry_zone_low, :entry_zone_high, :invalidation_price, numericality: { greater_than: 0 }
  validates :stock_id, uniqueness: { scope: :user_id, message: "is already on your watchlist" }
  validate :levels_are_ordered

  scope :tracked, -> { where.not(status: "archived") }

  def price_state_for(price)
    price = price.to_f
    return "invalidated" if price <= invalidation_price.to_f
    return "below_zone" if price < entry_zone_low.to_f
    return "in_zone" if price <= entry_zone_high.to_f

    "extended"
  end

  # Percent move needed to reach the bottom of the zone (negative once inside or above it).
  def distance_to_zone_pct(price = stock.last_price)
    price = price.to_f
    return nil unless price.positive?

    (((entry_zone_low.to_f - price) / price) * 100).round(2)
  end

  def risk_reward
    entry = entry_zone_low.to_f
    stop = stop_loss_price.to_f
    target = target_price.to_f
    return nil unless stop.positive? && target.positive? && entry > stop

    ((target - entry) / (entry - stop)).round(2)
  end

  private

  def levels_are_ordered
    return if entry_zone_low.blank? || entry_zone_high.blank? || invalidation_price.blank?

    errors.add(:entry_zone_high, "must be at or above the zone low") if entry_zone_high < entry_zone_low
    errors.add(:invalidation_price, "must be below the entry zone") if invalidation_price >= entry_zone_low
    if stop_loss_price.present? && stop_loss_price >= entry_zone_low
      errors.add(:stop_loss_price, "must be below the entry zone")
    end
    if target_price.present? && target_price <= entry_zone_high
      errors.add(:target_price, "must be above the entry zone")
    end
  end
end
