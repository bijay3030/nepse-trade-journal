class TradeResultSerializer < ActiveModel::Serializer
  attributes :id, :trade_execution_id, :exit_price, :exit_date, :exit_reason, :exit_efficiency,
             :max_price_reached, :min_price_reached, :exit_broker_fees, :mistake_tags,
             :lesson_learned, :emotional_state_at_exit, :gross_pnl, :net_pnl, :is_win

  def is_win
    object.is_win?
  end
end
