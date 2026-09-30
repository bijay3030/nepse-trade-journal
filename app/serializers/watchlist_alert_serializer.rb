class WatchlistAlertSerializer < ActiveModel::Serializer
  attributes :id, :watchlist_item_id, :symbol, :kind, :message, :price, :relative_volume, :read_at, :created_at

  def symbol = object.watchlist_item.stock.symbol
  def price = object.price&.to_f
  def relative_volume = object.relative_volume&.to_f
end
