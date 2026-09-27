class TradeExecutionSerializer < ActiveModel::Serializer
  attributes :id, :trade_plan_id, :actual_entry_price, :quantity, :entry_time,
             :broker, :broker_fees, :order_type, :entry_efficiency, :notes, :total_cost
end
