class TradeExecution < ApplicationRecord
  include SoftDeletable
  include Auditable

  belongs_to :trade_plan
  has_one :trade_result, dependent: :destroy

  delegate :user, to: :trade_plan

  validates :actual_entry_price, :quantity, :entry_time, presence: true

  def total_cost
    (actual_entry_price * quantity) + broker_fees
  end
end
