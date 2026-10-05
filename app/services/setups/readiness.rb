module Setups
  # Buy-readiness score, 0-100: how many of the conditions for an entry are in
  # place. It describes the chart against fixed rules; it is not a recommendation.
  #
  #   trend   30  share of the 8 trend-template rules passed
  #   setup   25  quality of the best setup (VCP score, or price-action confidence)
  #   market  15  strong 15, neutral 9, weak 3
  #   sector  15  sector index vs NEPSE over 20 sessions: +3 pts or more = 15, -3 or less = 0
  #   flow    15  broker flow score (Flows::AccumulationAnalyzer): +20 or more = 15, -20 or less = 0
  # Missing sector index or flow data scores half, so it neither helps nor hurts much.
  module Readiness
    WEIGHTS = { trend: 30, setup: 25, market: 15, sector: 15, flow: 15 }.freeze
    MARKET_POINTS = { "strong" => 15, "neutral" => 9, "weak" => 3 }.freeze
    SECTOR_SPREAD = 3.0
    FLOW_SPREAD = 20.0

    # "In buy zone" on the board (balanced): price in the zone, most trend rules, decent readiness.
    MIN_PRICE_RULES = 5
    MIN_READINESS = 60

    module_function

    def call(trend_passed:, setup_quality:, regime:, sector_return:, nepse_return:, flow_score: nil)
      relative = sector_return && nepse_return ? (sector_return - nepse_return) : nil
      components = {
        trend: (trend_passed.to_f / 8 * WEIGHTS[:trend]).round,
        setup: (setup_quality.to_f.clamp(0, 100) / 100 * WEIGHTS[:setup]).round,
        market: MARKET_POINTS.fetch(regime.to_s, 9),
        sector: scaled(relative, SECTOR_SPREAD, WEIGHTS[:sector]),
        flow: scaled(flow_score&.to_f, FLOW_SPREAD, WEIGHTS[:flow])
      }
      {
        score: components.values.sum,
        components: components.to_h { |key, points| [ key, { points: points, max: WEIGHTS[key] } ] }
                              .merge(sector_vs_nepse: relative&.round(2), flow_score: flow_score&.to_f)
      }
    end

    # Linear from -spread (0 points) to +spread (full points); nil gives half.
    def scaled(value, spread, max)
      return max / 2 if value.nil?

      (((value + spread) / (2 * spread)).clamp(0, 1) * max).round
    end

    # Setups that can put a stock on "Entry zone now". Support pullbacks are shown in the
    # screener but kept off the board: in the backtest they lost (14 trades, 36% win)
    # while pullbacks to a rising average won about 70%.
    BOARD_SETUP_TYPES = Types::ALL - %w[pullback]

    def in_buy_zone?(zone_state:, price_rules_passed:, score:, setup_type:)
      zone_state == "in_zone" && BOARD_SETUP_TYPES.include?(setup_type) &&
        price_rules_passed >= MIN_PRICE_RULES && score >= MIN_READINESS
    end
  end
end
