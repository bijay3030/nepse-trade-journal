# Adapts the application's existing analysis engines to the dashboard API contract.
class Stock::SetupAnalysis
  COMPONENTS = {
    trend: ["Trend", 20], price_contraction: ["Contraction", 25],
    volume_contraction: ["Volume", 20], tightness: ["Tightness", 15],
    pivot_proximity: ["Pivot proximity", 20]
  }.freeze

  def initialize(stock, market:)
    @stock = stock
    @market = market
    @prices = stock.daily_prices.sort_by(&:traded_on).last(200)
    @indicators = stock.daily_indicators.index_by(&:traded_on)
  end

  def summary
    latest = @prices.last
    {
      symbol: @stock.symbol, sector: @stock.sector, current_price: latest.close_price.to_f,
      change_percent: latest.change_percent.to_f, volume: latest.volume,
      vcp_score: vcp[:setup_quality_score], price_action_state: action[:structure], trend_state: trend,
      liquidity_rating: liquidity, pivot: vcp[:pivot_level], distance_to_pivot: vcp[:distance_to_pivot_pct],
      is_pivot_near: vcp[:is_pivot_near] || false,
      setup_state: setup_state, market_regime: @market[:regime_status]
    }
  end

  def detail
    latest = @prices.last
    sector = @market[:sectors].find { |row| row[:sector] == @stock.sector }
    {
      symbol: @stock.symbol, name: @stock.name, sector: @stock.sector,
      current_price: latest&.close_price&.to_f || 0, change_percent: latest&.change_percent&.to_f || 0,
      setup_state: setup_state,
      vcp: { pivot_level: nil, distance_to_pivot_pct: nil, volume_behavior: nil,
             contraction_sequence_text: nil, above_sma50: nil, above_sma200: nil,
             base_high: nil, base_low: nil, base_duration_bars: nil,
             contractions_count: 0, contractions: [] }.merge(vcp.slice(:is_vcp_setup, :setup_quality_score, :classification, :base_high, :base_low,
                     :base_duration_bars, :contractions_count, :contractions, :contraction_sequence_text,
                     :volume_behavior, :pivot_level, :distance_to_pivot_pct, :above_sma50, :above_sma200)),
      vcp_breakdown: COMPONENTS.map do |key, (label, max)|
        { component: key, label: label, score: vcp.fetch(:score_breakdown, {}).fetch(key, 0), max: max }
      end,
      price_action: action.slice(:trend, :structure, :swing_highs, :swing_lows, :support_levels,
                                 :resistance_levels, :breakout_level, :distance_to_breakout, :confidence).merge(trend: trend),
      candles: @prices.map { |price| candle(price) },
      market: @market.slice(:regime_status, :index_trend, :market_breadth_pct),
      sector_context: sector && {
        name: sector[:sector], sector_performance_pct: sector[:sector_performance_pct],
        sector_trend: sector[:sector_trend], relative_strength_rating: sector[:relative_strength_rating]
      }
    }
  end

  private

  def vcp
    @vcp ||= Vcp::DetectionEngine.call(@prices)
  end

  def action
    @action ||= PriceAction::AnalyzerService.call(@prices)
  end

  def trend
    %w[uptrend sideways downtrend].include?(action[:trend]) ? action[:trend] : "sideways"
  end

  def liquidity
    # The liquidity engine classifies from traded value, not share count.
    @liquidity ||= MarketContext::LiquidityEvaluator.call(@stock)[:rating]
  end

  def setup_state
    return "invalidated" if vcp[:reason]&.include?("broke down")
    return "watch" unless vcp[:pivot_level]

    distance = vcp[:distance_to_pivot_pct]
    prior_breakout = @prices.last(10).first(9).any? { |price| price.close_price.to_f > vcp[:pivot_level] }
    return "failed_breakout" if prior_breakout && distance.positive?
    return "breakout" if distance <= 0
    return "near_pivot" if distance <= 2

    "watch"
  end

  def candle(price)
    indicator = @indicators[price.traded_on]
    {
      traded_on: price.traded_on.iso8601, open: price.open_price.to_f, high: price.high_price.to_f,
      low: price.low_price.to_f, close: price.close_price.to_f, volume: price.volume,
      sma_20: indicator&.sma_20&.to_f, sma_50: indicator&.sma_50&.to_f, sma_200: indicator&.sma_200&.to_f
    }
  end
end
