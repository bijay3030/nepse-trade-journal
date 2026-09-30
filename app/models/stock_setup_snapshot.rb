# Nightly analysis of one stock for one session. See Setups::SnapshotBuilder.
class StockSetupSnapshot < ApplicationRecord
  # too_early: below the entry zone; in_zone: inside it; extended: above it;
  # failed: at or below the invalidation level; no_setup: no zone could be built.
  ZONE_STATES = %w[too_early in_zone extended failed no_setup].freeze

  belongs_to :stock

  validates :traded_on, presence: true, uniqueness: { scope: :stock_id }
  validates :zone_state, inclusion: { in: ZONE_STATES }
  validates :flow_state, inclusion: { in: %w[accumulation distribution neutral no_data] }, allow_nil: true

  validate :known_guards

  scope :latest_session, -> { where(traded_on: maximum(:traded_on)) }
  # Charts that meet the entry-zone rules but fail a tradability guard.
  scope :held_back_by_guards, lambda {
    where(zone_state: "in_zone")
      .where("trend_rules_passed >= ? AND readiness_score >= ?", Setups::Readiness::MIN_PRICE_RULES, Setups::Readiness::MIN_READINESS)
      .where("guards <> '[]'::jsonb")
  }

  private

  def known_guards
    errors.add(:guards, "has unknown values") unless guards.is_a?(Array) && (guards - Setups::Guards::ALL).empty?
  end
end
