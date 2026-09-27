class TradePlanSerializer < ActiveModel::Serializer
  attributes :id, :status, :entry_strategy, :analysis_type, :planned_entry_price,
             :target_price, :stop_loss_price, :planned_quantity, :created_at

  belongs_to :stock
  belongs_to :trading_strategy
  has_one :trade_execution
  has_one :trade_result
end
