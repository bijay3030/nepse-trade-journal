module Setups
  # Buy-readiness score, 0-100: how many of the conditions for an entry are in
  # place. It describes the chart against fixed rules; it is not a recommendation.
  #
  #   trend   30  share of the 8 trend-template rules passed
  #   rs      20  RS rating: 0 at 40 or below, rising to full at 70-89; 90+ scores 15
  #               (the strongest leaders pulled back more often after entry)
  #   setup   20  quality of the best setup (VCP score, or price-action confidence)
  #   flow    15  broker flow score (Flows::AccumulationAnalyzer): +20 or more = 15, -20 or less = 0
  #   sector  10  sector index vs NEPSE over 20 sessions: +3 pts or more = 10, -3 or less = 0
  #   market   5  strong 5, neutral 3, weak 1
  # Missing RS, sector index or flow data scores half, so it neither helps nor hurts much.
  #
  # Weights were set from the backtest (Apr-Oct 2026): trend rules, RS 70-89 and broker
  # accumulation separated later returns; the sector and market regime inputs didn't
  # (the regime pointed the wrong way), so they now count little.
  module Readiness
    WEIGHTS = { trend: 30, rs: 20, setup: 20, flow: 15, sector: 10, market: 5 }.freeze
    MARKET_POINTS = { "strong" => 5, "neutral" => 3, "weak" => 1 }.freeze
    RS_FLOOR = 40
    RS_FULL = 70
    RS_LEADER = 90
    SECTOR_SPREAD = 3.0
    FLOW_SPREAD = 20.0

    # "In buy zone" on the board (balanced): price in the zone, most trend rules, decent readiness.
    MIN_PRICE_RULES = 5
    MIN_READINESS = 60

    module_function

    def call(trend_passed:, setup_quality:, regime:, sector_return:, nepse_return:, flow_score: nil, rs_rating: nil)
      relative = sector_return && nepse_return ? (sector_return - nepse_return) : nil
      components = {
        trend: (trend_passed.to_f / 8 * WEIGHTS[:trend]).round,
        rs: rs_points(rs_rating),
        setup: (setup_quality.to_f.clamp(0, 100) / 100 * WEIGHTS[:setup]).round,
        market: MARKET_POINTS.fetch(regime.to_s, MARKET_POINTS["neutral"]),
        sector: scaled(relative, SECTOR_SPREAD, WEIGHTS[:sector]),
        flow: scaled(flow_score&.to_f, FLOW_SPREAD, WEIGHTS[:flow])
      }
      {
        score: components.values.sum,
        components: components.to_h { |key, points| [ key, { points: points, max: WEIGHTS[key] } ] }
                              .merge(sector_vs_nepse: relative&.round(2), flow_score: flow_score&.to_f)
      }
    end

    def rs_points(rating)
      max = WEIGHTS[:rs]
      return max / 2 if rating.nil?
      return (max * 0.75).round if rating >= RS_LEADER

      ((rating - RS_FLOOR).clamp(0, RS_FULL - RS_FLOOR).to_f / (RS_FULL - RS_FLOOR) * max).round
    end

    # Linear from -spread (0 points) to +spread (full points); nil gives half.
    def scaled(value, spread, max)
      return max / 2 if value.nil?

      (((value + spread) / (2 * spread)).clamp(0, 1) * max).round
    end

    def in_buy_zone?(zone_state:, price_rules_passed:, score:)
      zone_state == "in_zone" && price_rules_passed >= MIN_PRICE_RULES && score >= MIN_READINESS
    end
  end
end
