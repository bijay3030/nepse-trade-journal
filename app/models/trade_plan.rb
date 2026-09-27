class TradePlan < ApplicationRecord
  include SoftDeletable
  include Auditable

  belongs_to :user
  belongs_to :stock
  belongs_to :trading_strategy, optional: true

  has_one :trade_execution, dependent: :destroy
  has_one :trade_result, through: :trade_execution

  scope :recent, -> { order(created_at: :desc) }

  validates :status, presence: true
end
