module Setups
  # Buy-readiness score, 0-100: how many of the conditions for an entry are in
  # place. It describes the chart against fixed rules; it is not a recommendation.
  #
  #   trend   35  share of the 8 trend-template rules passed
  #   setup   30  quality of the best setup (VCP score, or price-action confidence)
  #   market  15  strong 15, neutral 9, weak 3
  #   sector  20  sector index vs NEPSE over 20 sessions: +3 pts or more = 20, -3 or less = 0
  module Readiness
    WEIGHTS = { trend: 35, setup: 30, market: 15, sector: 20 }.freeze
    MARKET_POINTS = { "strong" => 15, "neutral" => 9, "weak" => 3 }.freeze
    SECTOR_SPREAD = 3.0

    # "In buy zone" on the board (balanced): price in the zone, most trend rules, decent readiness.
    MIN_PRICE_RULES = 5
    MIN_READINESS = 60

    module_function

    def call(trend_passed:, setup_quality:, regime:, sector_return:, nepse_return:)
      relative = sector_return && nepse_return ? (sector_return - nepse_return) : nil
      components = {
        trend: (trend_passed.to_f / 8 * WEIGHTS[:trend]).round,
        setup: (setup_quality.to_f.clamp(0, 100) / 100 * WEIGHTS[:setup]).round,
        market: MARKET_POINTS.fetch(regime.to_s, 9),
        sector: relative.nil? ? WEIGHTS[:sector] / 2 : (((relative + SECTOR_SPREAD) / (2 * SECTOR_SPREAD)).clamp(0, 1) * WEIGHTS[:sector]).round
      }
      {
        score: components.values.sum,
        components: components.to_h { |key, points| [ key, { points: points, max: WEIGHTS[key] } ] }
                              .merge(sector_vs_nepse: relative&.round(2))
      }
    end

    def in_buy_zone?(zone_state:, price_rules_passed:, score:)
      zone_state == "in_zone" && price_rules_passed >= MIN_PRICE_RULES && score >= MIN_READINESS
    end
  end
end
