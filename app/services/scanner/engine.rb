module Scanner
  class Engine
    VCP_COMPONENT_MAXIMA = {
      trend: 20,
      price_contraction: 25,
      volume_contraction: 20,
      tightness: 15,
      pivot_proximity: 20
    }.freeze

    VCP_COMPONENT_LABELS = {
      trend: "Trend",
      price_contraction: "Contraction",
      volume_contraction: "Volume",
      tightness: "Tightness",
      pivot_proximity: "Pivot proximity"
    }.freeze

    def self.call(stocks: nil, date: nil, config: Configuration.new)
      new(stocks: stocks, date: date, config: config).scan
    end

    def initialize(stocks: nil, date: nil, config: Configuration.new)
      @config = config
      @date = date.present? ? to_date(date) : resolve_latest_date
      @stocks = resolve_stocks(stocks)
      @sector_contexts = {}
    end

    def scan
      candidates = @stocks.map { |stock| evaluate_candidate(stock) }
      included = candidates.select { |candidate| candidate[:included] }
      included = included.sort_by { |candidate| -candidate[:vcp_score].to_f }
      included = included.first(@config.max_candidates) if @config.max_candidates

      return included if @config.only_included

      rejected = candidates.reject { |candidate| candidate[:included] }
                          .sort_by { |candidate| -candidate[:vcp_score].to_f }
      included + rejected
    end

    private

    def evaluate_candidate(stock)
      records = load_records(stock)
      indicator = indicator_snapshot(stock, records)
      price = current_price(stock, records)

      candidate = base_candidate(stock, price)
      candidate[:liquidity_metrics] = MarketContext::LiquidityEvaluator.call(stock, @config.market_config)
      candidate[:volume_state] = volume_state(indicator)
      candidate[:rvol] = indicator[:rvol]

      stage_liquidity(candidate)
      return candidate if excluded?(candidate)

      stage_trend(candidate, indicator)
      return candidate if excluded?(candidate)

      stage_price_position(candidate, indicator)
      return candidate if excluded?(candidate)

      vcp = Vcp::DetectionEngine.call(records, @config.vcp_config)
      stage_vcp(candidate, vcp)
      return candidate if excluded?(candidate)

      price_action = PriceAction::AnalyzerService.call(records, @config.price_action_config)
      stage_price_action(candidate, price_action)
      return candidate if excluded?(candidate)

      stage_context(candidate)
      candidate
    end

    def base_candidate(stock, price)
      {
        symbol: stock.symbol,
        stock_id: stock.id,
        sector: stock.sector,
        traded_on: @date,
        current_price: price,
        included: true,
        excluded_at_stage: nil,
        reasons_for_inclusion: [],
        reasons_for_exclusion: []
      }
    end

    def stage_liquidity(candidate)
      liquidity = candidate[:liquidity_metrics]

      if rating_rank(liquidity[:rating]) < rating_rank(@config.min_liquidity_rating)
        exclude(candidate, :liquidity,
                "Liquidity rating #{liquidity[:rating]} is below required #{@config.min_liquidity_rating}")
      elsif @config.min_avg_turnover && liquidity[:avg_turnover_20d] < @config.min_avg_turnover
        exclude(candidate, :liquidity,
                "20d average turnover #{liquidity[:avg_turnover_20d]} is below minimum #{@config.min_avg_turnover}")
      elsif @config.min_trading_frequency_pct && liquidity[:trading_frequency_pct] < @config.min_trading_frequency_pct
        exclude(candidate, :liquidity,
                "Trading frequency #{liquidity[:trading_frequency_pct]}% is below minimum #{@config.min_trading_frequency_pct}%")
      elsif @config.min_avg_daily_trades && liquidity[:avg_daily_trades] < @config.min_avg_daily_trades
        exclude(candidate, :liquidity,
                "Average daily trades #{liquidity[:avg_daily_trades]} is below minimum #{@config.min_avg_daily_trades}")
      else
        include_reason(candidate, "Liquidity #{liquidity[:rating]} (20d avg turnover #{delimit(liquidity[:avg_turnover_20d])})")
      end
    end

    def stage_trend(candidate, indicator)
      candidate[:sma_50] = indicator[:sma_50]
      candidate[:sma_200] = indicator[:sma_200]
      candidate[:above_sma50] = indicator[:sma_50].present? && candidate[:current_price] >= indicator[:sma_50]
      candidate[:above_sma200] = indicator[:sma_200].present? && candidate[:current_price] >= indicator[:sma_200]
      candidate[:trend_state] = derive_trend(candidate[:current_price], indicator[:sma_50], indicator[:sma_200])

      if @config.allowed_trends && !@config.allowed_trends.include?(candidate[:trend_state])
        exclude(candidate, :trend,
                "Trend state #{candidate[:trend_state]} not in allowed trends #{@config.allowed_trends.join(', ')}")
      elsif @config.require_above_sma50 && !candidate[:above_sma50]
        exclude(candidate, :trend, "Price #{candidate[:current_price]} is not above the 50-period SMA")
      elsif @config.require_above_sma200 && !candidate[:above_sma200]
        exclude(candidate, :trend, "Price #{candidate[:current_price]} is not above the 200-period SMA")
      else
        include_reason(candidate, "Trend #{candidate[:trend_state]} with price #{candidate[:above_sma50] ? 'above' : 'below'} the 50-period SMA")
      end
    end

    def stage_price_position(candidate, indicator)
      candidate[:high_52w] = indicator[:high_52w]
      candidate[:pct_below_high_52w] = indicator[:pct_below_high_52w]
      candidate[:pct_above_low_52w] = indicator[:pct_above_low_52w]

      if @config.max_pct_below_52w_high &&
         (candidate[:pct_below_high_52w].nil? || candidate[:pct_below_high_52w] > @config.max_pct_below_52w_high)
        exclude(candidate, :price_position,
                "Distance below 52-week high #{candidate[:pct_below_high_52w]}% exceeds maximum #{@config.max_pct_below_52w_high}%")
      elsif @config.min_pct_above_52w_low &&
            (candidate[:pct_above_low_52w].nil? || candidate[:pct_above_low_52w] < @config.min_pct_above_52w_low)
        exclude(candidate, :price_position,
                "Distance above 52-week low #{candidate[:pct_above_low_52w]}% is below minimum #{@config.min_pct_above_52w_low}%")
      else
        include_reason(candidate, "Price is #{candidate[:pct_below_high_52w]}% below its 52-week high")
      end
    end

    def stage_vcp(candidate, vcp)
      candidate[:vcp_score] = vcp[:setup_quality_score].to_f
      candidate[:vcp_classification] = vcp[:classification]
      candidate[:vcp_contractions_count] = vcp[:contractions_count]
      candidate[:pivot] = vcp[:pivot_level]
      candidate[:distance_to_pivot] = vcp[:distance_to_pivot_pct]
      candidate[:vcp_breakdown] = build_vcp_breakdown(vcp[:score_breakdown])

      if candidate[:vcp_score] < @config.min_vcp_score
        exclude(candidate, :vcp,
                "VCP score #{candidate[:vcp_score]} is below minimum #{@config.min_vcp_score}")
      elsif @config.required_vcp_classifications &&
            !@config.required_vcp_classifications.include?(candidate[:vcp_classification])
        exclude(candidate, :vcp,
                "VCP classification #{candidate[:vcp_classification]} not in #{@config.required_vcp_classifications.join(', ')}")
      elsif @config.max_distance_to_pivot_pct &&
            (candidate[:distance_to_pivot].nil? ||
             candidate[:distance_to_pivot].abs > @config.max_distance_to_pivot_pct)
        exclude(candidate, :vcp,
                "Distance to pivot #{candidate[:distance_to_pivot]}% exceeds maximum #{@config.max_distance_to_pivot_pct}%")
      else
        include_reason(candidate, "VCP score #{candidate[:vcp_score]} (#{candidate[:vcp_classification]})")
      end
    end

    def stage_price_action(candidate, price_action)
      candidate[:price_action_state] = price_action[:structure]
      candidate[:price_action_trend] = price_action[:trend]
      candidate[:price_action_confidence] = price_action[:confidence]
      candidate[:support] = nearest_level(price_action[:support_levels])
      candidate[:resistance] = nearest_level(price_action[:resistance_levels])
      candidate[:breakout_level] = price_action[:breakout_level]
      candidate[:distance_to_breakout] = price_action[:distance_to_breakout]
      candidate[:is_breakout_near] = price_action[:is_breakout_near]

      if @config.allowed_structures && !@config.allowed_structures.include?(candidate[:price_action_state])
        exclude(candidate, :price_action,
                "Structure #{candidate[:price_action_state]} not in allowed structures #{@config.allowed_structures.join(', ')}")
      elsif @config.require_breakout_near && !candidate[:is_breakout_near]
        exclude(candidate, :price_action,
                "Price is #{candidate[:distance_to_breakout]}% from breakout, outside proximity tolerance")
      elsif @config.max_distance_to_breakout_pct &&
            (candidate[:distance_to_breakout].nil? ||
             candidate[:distance_to_breakout] > @config.max_distance_to_breakout_pct)
        exclude(candidate, :price_action,
                "Distance to breakout #{candidate[:distance_to_breakout]}% exceeds maximum #{@config.max_distance_to_breakout_pct}%")
      else
        include_reason(candidate, "Price action #{candidate[:price_action_state]} with #{candidate[:distance_to_breakout]}% to resistance")
      end
    end

    def stage_context(candidate)
      market = market_context
      sector = sector_context(candidate[:sector])
      candidate[:market_regime] = market[:regime_status]
      candidate[:market_context] = market
      candidate[:sector_context] = sector

      if @config.allowed_regimes && !@config.allowed_regimes.include?(candidate[:market_regime])
        exclude(candidate, :context,
                "Market regime #{candidate[:market_regime]} not in allowed regimes #{@config.allowed_regimes.join(', ')}")
      elsif @config.allowed_sector_strengths &&
            !@config.allowed_sector_strengths.include?(sector[:relative_strength_rating])
        exclude(candidate, :context,
                "Sector relative strength #{sector[:relative_strength_rating]} not in allowed strengths #{@config.allowed_sector_strengths.join(', ')}")
      else
        include_reason(candidate, "Market regime #{candidate[:market_regime]}; sector #{candidate[:sector]} relative strength #{sector[:relative_strength_rating]}")
      end
    end

    def derive_trend(price, sma50, sma200)
      if sma50 && sma200
        if price > sma50 && sma50 > sma200
          "uptrend"
        elsif price < sma50 && sma50 < sma200
          "downtrend"
        else
          "sideways"
        end
      elsif sma50
        price >= sma50 ? "uptrend" : "downtrend"
      else
        "sideways"
      end
    end

    def volume_state(indicator)
      rvol = indicator[:rvol]
      return "unknown" if rvol.nil?

      if rvol >= @config.high_volume_rvol
        "high"
      elsif rvol <= @config.low_volume_rvol
        "low"
      else
        "normal"
      end
    end

    def build_vcp_breakdown(score_breakdown)
      score_breakdown.to_h.map do |component, score|
        {
          component: component.to_s,
          label: VCP_COMPONENT_LABELS.fetch(component.to_sym, component.to_s.titleize),
          score: score.to_i,
          max: VCP_COMPONENT_MAXIMA.fetch(component.to_sym, 0)
        }
      end
    end

    def nearest_level(levels)
      levels&.first&.fetch(:level, nil)
    end

    def include_reason(candidate, reason)
      candidate[:reasons_for_inclusion] << reason
    end

    def exclude(candidate, stage, reason)
      candidate[:included] = false
      candidate[:excluded_at_stage] = stage
      candidate[:reasons_for_exclusion] << reason
    end

    def excluded?(candidate)
      !candidate[:included]
    end

    def rating_rank(rating)
      MarketContext::LiquidityEvaluator.rating_rank(rating)
    end

    def market_context
      @market_context ||= MarketContext::RegimeEngine.call(@date, @config.market_config)
    end

    def sector_context(sector)
      @sector_contexts[sector] ||=
        MarketContext::SectorAnalyzer.call(sector, date: @date, config: @config.market_config)
    end

    def load_records(stock)
      stock.daily_prices.where(traded_on: ..@date).chronological.includes(:stock).to_a
    end

    def current_price(stock, records)
      (records.last&.close_price&.to_f || stock.last_price.to_f).round(2)
    end

    def indicator_snapshot(stock, records)
      indicator = stock.daily_indicators.where(traded_on: ..@date).order(traded_on: :desc).first
      return computed_snapshot(records) unless indicator&.sma_50

      {
        sma_20: indicator.sma_20&.to_f,
        sma_50: indicator.sma_50&.to_f,
        sma_200: indicator.sma_200&.to_f,
        rvol: indicator.rvol&.to_f,
        high_52w: indicator.high_52w&.to_f,
        pct_below_high_52w: indicator.pct_below_high_52w&.to_f,
        pct_above_low_52w: indicator.pct_above_low_52w&.to_f,
        avg_volume_20: indicator.avg_volume_20.to_i,
        source: :indicator
      }
    end

    def computed_snapshot(records)
      return empty_snapshot if records.empty?

      closes = records.map { |record| record.close_price.to_f }
      price = closes.last
      sma = ->(period) { closes.size >= period ? (closes.last(period).sum / period.to_f).round(2) : nil }

      window = records.last(250)
      high = window.map { |record| record.high_price.to_f }.max
      low = window.map { |record| record.low_price.to_f }.min
      avg_volume_20 = average_volume(records.last(20))

      {
        sma_20: sma.call(20),
        sma_50: sma.call(50),
        sma_200: sma.call(200),
        rvol: relative_volume(records, avg_volume_20),
        high_52w: high&.round(2),
        pct_below_high_52w: percentage_from(high, price, :below),
        pct_above_low_52w: percentage_from(low, price, :above),
        avg_volume_20: avg_volume_20,
        source: :computed
      }
    end

    def empty_snapshot
      {
        sma_20: nil,
        sma_50: nil,
        sma_200: nil,
        rvol: nil,
        high_52w: nil,
        pct_below_high_52w: nil,
        pct_above_low_52w: nil,
        avg_volume_20: 0,
        source: :none
      }
    end

    def average_volume(records)
      return 0 if records.empty?

      (records.sum { |record| record.volume.to_i } / records.size.to_f).round
    end

    def relative_volume(records, avg_volume_20)
      return nil if avg_volume_20.nil? || avg_volume_20.zero? || records.empty?

      (records.last.volume.to_f / avg_volume_20).round(2)
    end

    def percentage_from(reference, price, direction)
      return nil if reference.nil? || reference.to_f <= 0

      delta = direction == :below ? (reference - price) : (price - reference)
      ((delta / reference.to_f) * 100.0).round(2)
    end

    def resolve_stocks(stocks)
      scope = stocks || Stock.active
      scope.respond_to?(:to_a) ? scope.to_a : Array(scope)
    end

    def resolve_latest_date
      StockDailyPrice.maximum(:traded_on) || Date.current
    end

    def delimit(value)
      ActiveSupport::NumberHelper.number_to_delimited(value.to_f.round)
    end

    def to_date(value)
      value.is_a?(Date) ? value : Date.parse(value.to_s)
    end
  end
end
