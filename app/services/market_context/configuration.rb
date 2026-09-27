module MarketContext
  class Configuration
    DEFAULT_HIGH_LIQUIDITY_TURNOVER = 10_000_000.0 # 1 crore Rs
    DEFAULT_MEDIUM_LIQUIDITY_TURNOVER = 2_500_000.0 # 25 lakhs Rs
    DEFAULT_LIQUIDITY_SHORT_WINDOW = 10
    DEFAULT_LIQUIDITY_MEDIUM_WINDOW = 20
    DEFAULT_LIQUIDITY_LONG_WINDOW = 50
    DEFAULT_TRADING_FREQUENCY_WINDOW = 20
    DEFAULT_MIN_TRADING_FREQUENCY_PCT = 50.0
    DEFAULT_MIN_AVG_DAILY_TRADES = 0

    DEFAULT_STRONG_REGIME_BREADTH_PCT = 60.0
    DEFAULT_WEAK_REGIME_BREADTH_PCT = 40.0
    DEFAULT_STRONG_AD_RATIO = 1.2
    DEFAULT_WEAK_AD_RATIO = 0.8
    DEFAULT_INDEX_TREND_WINDOW = 20

    DEFAULT_SECTOR_TREND_WINDOW = 20
    DEFAULT_SECTOR_TREND_THRESHOLD_PCT = 2.0
    DEFAULT_SECTOR_STRONG_RELATIVE_STRENGTH_PCT = 1.0
    DEFAULT_SECTOR_WEAK_RELATIVE_STRENGTH_PCT = -1.0

    LIQUIDITY_RATINGS = %w[low medium high].freeze

    attr_accessor :high_liquidity_turnover, :medium_liquidity_turnover,
                  :liquidity_short_window, :liquidity_medium_window,
                  :liquidity_long_window, :trading_frequency_window,
                  :min_trading_frequency_pct, :min_avg_daily_trades,
                  :strong_regime_breadth_pct, :weak_regime_breadth_pct,
                  :strong_ad_ratio, :weak_ad_ratio, :index_trend_window,
                  :sector_trend_window, :sector_trend_threshold_pct,
                  :sector_strong_relative_strength_pct,
                  :sector_weak_relative_strength_pct

    def initialize(
      high_liquidity_turnover: DEFAULT_HIGH_LIQUIDITY_TURNOVER,
      medium_liquidity_turnover: DEFAULT_MEDIUM_LIQUIDITY_TURNOVER,
      liquidity_short_window: DEFAULT_LIQUIDITY_SHORT_WINDOW,
      liquidity_medium_window: DEFAULT_LIQUIDITY_MEDIUM_WINDOW,
      liquidity_long_window: DEFAULT_LIQUIDITY_LONG_WINDOW,
      trading_frequency_window: DEFAULT_TRADING_FREQUENCY_WINDOW,
      min_trading_frequency_pct: DEFAULT_MIN_TRADING_FREQUENCY_PCT,
      min_avg_daily_trades: DEFAULT_MIN_AVG_DAILY_TRADES,
      strong_regime_breadth_pct: DEFAULT_STRONG_REGIME_BREADTH_PCT,
      weak_regime_breadth_pct: DEFAULT_WEAK_REGIME_BREADTH_PCT,
      strong_ad_ratio: DEFAULT_STRONG_AD_RATIO,
      weak_ad_ratio: DEFAULT_WEAK_AD_RATIO,
      index_trend_window: DEFAULT_INDEX_TREND_WINDOW,
      sector_trend_window: DEFAULT_SECTOR_TREND_WINDOW,
      sector_trend_threshold_pct: DEFAULT_SECTOR_TREND_THRESHOLD_PCT,
      sector_strong_relative_strength_pct: DEFAULT_SECTOR_STRONG_RELATIVE_STRENGTH_PCT,
      sector_weak_relative_strength_pct: DEFAULT_SECTOR_WEAK_RELATIVE_STRENGTH_PCT
    )
      @high_liquidity_turnover = [ high_liquidity_turnover.to_f, 1.0 ].max
      @medium_liquidity_turnover = [ medium_liquidity_turnover.to_f, 1.0 ].max
      @liquidity_short_window = [ liquidity_short_window.to_i, 1 ].max
      @liquidity_medium_window = [ liquidity_medium_window.to_i, @liquidity_short_window ].max
      @liquidity_long_window = [ liquidity_long_window.to_i, @liquidity_medium_window ].max
      @trading_frequency_window = [ trading_frequency_window.to_i, 1 ].max
      @min_trading_frequency_pct = min_trading_frequency_pct.to_f.clamp(0.0, 100.0)
      @min_avg_daily_trades = [ min_avg_daily_trades.to_i, 0 ].max
      @strong_regime_breadth_pct = strong_regime_breadth_pct.to_f.clamp(0.0, 100.0)
      @weak_regime_breadth_pct = weak_regime_breadth_pct.to_f.clamp(0.0, 100.0)
      @strong_ad_ratio = [ strong_ad_ratio.to_f, 0.1 ].max
      @weak_ad_ratio = [ weak_ad_ratio.to_f, 0.05 ].max
      @index_trend_window = [ index_trend_window.to_i, 1 ].max
      @sector_trend_window = [ sector_trend_window.to_i, 1 ].max
      @sector_trend_threshold_pct = [ sector_trend_threshold_pct.to_f, 0.0 ].max
      @sector_strong_relative_strength_pct = sector_strong_relative_strength_pct.to_f
      @sector_weak_relative_strength_pct = sector_weak_relative_strength_pct.to_f
    end
  end
end
