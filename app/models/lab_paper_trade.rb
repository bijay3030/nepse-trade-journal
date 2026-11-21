# A Strategy Lab candidate followed as a paper trade (Lab::PaperTrades).
class LabPaperTrade < ApplicationRecord
  STATUSES = %w[pending open closed skipped].freeze
  FINAL = %w[closed skipped].freeze

  belongs_to :stock

  validates :strategy, inclusion: { in: Lab::Strategies::KEYS }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where.not(status: FINAL) }

  # Levels with symbol keys, as Lab::Strategies.simulate expects.
  def levels = super.to_h.transform_keys(&:to_sym).transform_values { _1.is_a?(String) ? _1.to_f : _1 }
end
