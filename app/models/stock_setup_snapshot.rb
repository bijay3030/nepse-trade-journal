# Nightly analysis of one stock for one session. See Setups::SnapshotBuilder.
class StockSetupSnapshot < ApplicationRecord
  # too_early: below the entry zone; in_zone: inside it; extended: above it;
  # failed: at or below the invalidation level; no_setup: no zone could be built.
  ZONE_STATES = %w[too_early in_zone extended failed no_setup].freeze

  belongs_to :stock

  validates :traded_on, presence: true, uniqueness: { scope: :stock_id }
  validates :zone_state, inclusion: { in: ZONE_STATES }
  validates :flow_state, inclusion: { in: %w[accumulation distribution neutral no_data] }, allow_nil: true

  scope :latest_session, -> { where(traded_on: maximum(:traded_on)) }
end
