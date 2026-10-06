class PositionAlertSerializer < ActiveModel::Serializer
  attributes :id, :position_id, :kind, :message, :price, :read_at, :created_at, :symbol, :position_open, :stop_price, :break_even_price

  def symbol = object.position.stock.symbol
  def position_open = object.position.open?
  def price = object.price&.to_f
  def stop_price = object.position.stop_price.to_f
  # For the "Move stop to break-even" button on a +1R alert.
  def break_even_price = object.kind == "one_r" && object.position.open? ? object.position.break_even_price : nil
end
