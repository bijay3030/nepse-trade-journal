class TradeResult < ApplicationRecord
  include SoftDeletable
  include Auditable

  belongs_to :trade_execution

  delegate :trade_plan, to: :trade_execution
  delegate :user, to: :trade_plan

  validates :exit_price, :exit_date, presence: true

  def gross_pnl
    (exit_price - trade_execution.actual_entry_price) * trade_execution.quantity
  end

  def net_pnl
    gross_pnl - trade_execution.broker_fees - exit_broker_fees
  end

  def is_win?
    net_pnl.positive?
  end
end
