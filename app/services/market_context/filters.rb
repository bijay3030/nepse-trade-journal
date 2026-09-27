module MarketContext
  # Predicate helpers intended for scanner/alerting pipelines. They operate on
  # already-computed MarketContext results so a scan can compute the market
  # regime and sector context once per date and reuse it across many stocks.
  module Filters
    module_function

    def liquid?(stock, min_rating: "medium", min_trading_frequency_pct: nil,
                min_avg_daily_trades: nil, config: Configuration.new)
      LiquidityEvaluator.new(stock, config).passes?(
        min_rating: min_rating,
        min_trading_frequency_pct: min_trading_frequency_pct,
        min_avg_daily_trades: min_avg_daily_trades
      )
    end

    def regime_in?(regime_result, allowed: %w[strong neutral])
      allowed_include?(regime_result[:regime_status], allowed)
    end

    def market_breadth_at_least?(regime_result, pct)
      regime_result[:market_breadth_pct].to_f >= pct.to_f
    end

    def index_trend_in?(regime_result, allowed: %w[uptrend sideways])
      allowed_include?(regime_result[:index_trend], allowed)
    end

    def sector_strength_in?(sector_result, allowed: %w[strong neutral])
      allowed_include?(sector_result[:relative_strength_rating], allowed)
    end

    def sector_trend_in?(sector_result, allowed: %w[uptrend sideways])
      allowed_include?(sector_result[:sector_trend], allowed)
    end

    def sector_performance_at_least?(sector_result, pct)
      sector_result[:sector_performance_pct].to_f >= pct.to_f
    end

    def relative_strength_at_least?(sector_result, pct)
      sector_result[:relative_strength_pct].to_f >= pct.to_f
    end

    def allowed_include?(value, allowed)
      Array(allowed).map(&:to_s).include?(value.to_s)
    end
  end
end
