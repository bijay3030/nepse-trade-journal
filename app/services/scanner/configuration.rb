module Scanner
  class Configuration
    DEFAULT_MIN_LIQUIDITY_RATING = "medium"
    DEFAULT_ALLOWED_TRENDS = %w[uptrend].freeze
    DEFAULT_MIN_VCP_SCORE = 50.0
    DEFAULT_HIGH_VOLUME_RVOL = 1.5
    DEFAULT_LOW_VOLUME_RVOL = 0.7

    LIQUIDITY_RATINGS = %w[low medium high].freeze

    attr_accessor :min_liquidity_rating, :min_avg_turnover,
                  :min_trading_frequency_pct, :min_avg_daily_trades,
                  :allowed_trends, :require_above_sma50, :require_above_sma200,
                  :max_pct_below_52w_high, :min_pct_above_52w_low,
                  :min_vcp_score, :required_vcp_classifications,
                  :max_distance_to_pivot_pct,
                  :allowed_structures, :max_distance_to_breakout_pct,
                  :require_breakout_near,
                  :allowed_regimes, :allowed_sector_strengths,
                  :high_volume_rvol, :low_volume_rvol,
                  :only_included, :max_candidates,
                  :market_config, :vcp_config, :price_action_config

    def initialize(
      min_liquidity_rating: DEFAULT_MIN_LIQUIDITY_RATING,
      min_avg_turnover: nil,
      min_trading_frequency_pct: nil,
      min_avg_daily_trades: nil,
      allowed_trends: DEFAULT_ALLOWED_TRENDS,
      require_above_sma50: true,
      require_above_sma200: false,
      max_pct_below_52w_high: nil,
      min_pct_above_52w_low: nil,
      min_vcp_score: DEFAULT_MIN_VCP_SCORE,
      required_vcp_classifications: nil,
      max_distance_to_pivot_pct: nil,
      allowed_structures: nil,
      max_distance_to_breakout_pct: nil,
      require_breakout_near: false,
      allowed_regimes: nil,
      allowed_sector_strengths: nil,
      high_volume_rvol: DEFAULT_HIGH_VOLUME_RVOL,
      low_volume_rvol: DEFAULT_LOW_VOLUME_RVOL,
      only_included: true,
      max_candidates: nil,
      market_config: MarketContext::Configuration.new,
      vcp_config: Vcp::Configuration.new,
      price_action_config: PriceAction::Configuration.new
    )
      @min_liquidity_rating = min_liquidity_rating.to_s
      @min_avg_turnover = optional_number(min_avg_turnover)
      @min_trading_frequency_pct = optional_number(min_trading_frequency_pct)
      @min_avg_daily_trades = min_avg_daily_trades.nil? ? nil : [ min_avg_daily_trades.to_i, 0 ].max
      @allowed_trends = normalize_list(allowed_trends)
      @require_above_sma50 = !!require_above_sma50
      @require_above_sma200 = !!require_above_sma200
      @max_pct_below_52w_high = optional_number(max_pct_below_52w_high)
      @min_pct_above_52w_low = optional_number(min_pct_above_52w_low)
      @min_vcp_score = min_vcp_score.to_f
      @required_vcp_classifications = normalize_list(required_vcp_classifications)
      @max_distance_to_pivot_pct = optional_number(max_distance_to_pivot_pct)
      @allowed_structures = normalize_list(allowed_structures)
      @max_distance_to_breakout_pct = optional_number(max_distance_to_breakout_pct)
      @require_breakout_near = !!require_breakout_near
      @allowed_regimes = normalize_list(allowed_regimes)
      @allowed_sector_strengths = normalize_list(allowed_sector_strengths)
      @high_volume_rvol = [ high_volume_rvol.to_f, 0.0 ].max
      @low_volume_rvol = [ low_volume_rvol.to_f, 0.0 ].max
      @only_included = !!only_included
      @max_candidates = max_candidates.nil? ? nil : [ max_candidates.to_i, 1 ].max
      @market_config = market_config
      @vcp_config = vcp_config
      @price_action_config = price_action_config
    end

    private

    def optional_number(value)
      value.nil? ? nil : value.to_f
    end

    def normalize_list(value)
      value.nil? ? nil : Array(value).map(&:to_s)
    end
  end
end
