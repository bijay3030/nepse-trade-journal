class TradePlanDetailSerializer < ActiveModel::Serializer
  attributes :id, :status, :entry_strategy, :analysis_type,
             :entry_trigger_description, :planned_entry_price, :target_price,
             :stop_loss_price, :position_size_percent, :planned_quantity,
             :expected_hold_duration, :market_condition_at_entry,
             :emotional_state_at_entry, :sector_trend, :news_catalyst,
             :created_at, :updated_at

  belongs_to :stock
  belongs_to :trading_strategy
  has_one :trade_execution
  has_one :trade_result
end
