class StockSetupSnapshotSerializer < ActiveModel::Serializer
  PRICE_FIELDS = %i[close_price entry_zone_low entry_zone_high invalidation_price target_price pivot_price distance_to_zone_pct].freeze

  attributes :traded_on, :setup_type, :zone_state, :in_buy_zone, :readiness_score, :readiness_components,
             :trend_rules_passed, :trend_checks, :rs_rating, :setup_quality, :flow_state, :flow_score, :avg_turnover, :change_pct, :guards, :extension, *PRICE_FIELDS

  def flow_score = object.flow_score&.to_f
  def avg_turnover = object.avg_turnover&.to_f
  def change_pct = object.change_pct&.to_f

  PRICE_FIELDS.each do |field|
    define_method(field) { object.public_send(field)&.to_f }
  end
end
