class PositionSerializer < ActiveModel::Serializer
  attributes :id, :symbol, :name, :sector, :status, :setup_type, :watchlist_item_id,
             :quantity, :average_price, :last_price, :change_percent, :price_updated_at,
             :stop_price, :initial_stop_price, :target_price, :unrealized_pnl, :unrealized_pct, :r_multiple,
             :open_risk, :cost_basis, :net_pnl_if_sold, :break_even_price, :opened_on, :sellable_on, :days_held, :closed_on, :notes, :fills, :latest_alert,
             :realized, :average_sell_price, :closed_r_multiple, :excursions, :settled_quantity, :review

  def symbol = object.stock.symbol
  def name = object.stock.name
  def sector = object.stock.sector
  def change_percent = object.stock.change_percent.to_f
  def price_updated_at = object.stock.last_updated
  def stop_price = object.stop_price.to_f
  def initial_stop_price = object.initial_stop_price.to_f
  def target_price = object.target_price&.to_f

  # The newest sell-rule alert, shown on the position's card.
  def latest_alert
    alert = object.alerts.max_by(&:created_at)
    alert && { id: alert.id, kind: alert.kind, message: alert.message, created_at: alert.created_at, read: alert.read_at.present? }
  end

  def excursions = object.open? ? nil : object.excursions

  def review
    { plan_followed: object.review_plan_followed, tags: object.review_tags, lesson: object.review_lesson, reviewed_at: object.reviewed_at }
  end

  def fills
    object.fills.map do |fill|
      { id: fill.id, side: fill.side, price: fill.price.to_f, quantity: fill.quantity, traded_on: fill.traded_on.iso8601 }
    end
  end
end
