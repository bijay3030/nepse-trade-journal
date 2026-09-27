class WatchlistItemSerializer < ActiveModel::Serializer
  PRICE_FIELDS = %i[entry_zone_low entry_zone_high invalidation_price stop_loss_price target_price pivot_price price_at_add].freeze

  attributes :id, :symbol, :name, :sector, :setup_type, :status, :price_state, *PRICE_FIELDS,
             :current_price, :change_percent, :price_updated_at, :distance_to_zone_pct, :risk_reward,
             :setup_snapshot, :notes, :trade_plan_id, :last_evaluated_at, :created_at

  # Decimals are sent as numbers, not strings.
  PRICE_FIELDS.each do |field|
    define_method(field) { object.public_send(field)&.to_f }
  end

  def symbol = object.stock.symbol
  def name = object.stock.name
  def sector = object.stock.sector
  def current_price = object.stock.last_price.to_f
  def change_percent = object.stock.change_percent.to_f
  def price_updated_at = object.stock.last_updated
  def distance_to_zone_pct = object.distance_to_zone_pct
  def risk_reward = object.risk_reward
end
