// Shared API contract for the market analysis dashboard.
// Backend endpoints (Rails, /api/v1) must serialize exactly these shapes.

export type MarketRegime = "strong" | "neutral" | "weak"
export type IndexTrend = "uptrend" | "sideways" | "downtrend"
export type TrendState = "uptrend" | "sideways" | "downtrend"
export type LiquidityRating = "high" | "medium" | "low"
export type VolumeState = "high" | "normal" | "low" | "unknown"

/** Neutral price-action states. Never render trading advice such as "BUY". */
export type SetupState = "watch" | "near_pivot" | "breakout" | "failed_breakout" | "invalidated"

export const SETUP_STATE_LABELS: Record<SetupState, string> = {
  watch: "Watch",
  near_pivot: "Near Pivot",
  breakout: "Breakout",
  failed_breakout: "Failed Breakout",
  invalidated: "Invalidated",
}

export type IndexHistoryPoint = { traded_on: string; value: number }

export type SectorOverviewRow = {
  sector: string
  constituents_count: number
  advancing_stocks: number
  declining_stocks: number
  sector_performance_pct: number
  sector_turnover: number
  relative_strength_pct: number | null
  relative_strength_rating: "strong" | "neutral" | "weak"
  sector_trend: TrendState
  pct_above_sma50: number
}

/** GET /market/overview */
export type MarketOverview = {
  traded_on: string | null
  regime_status: MarketRegime
  nepse_index: number
  index_change_pct: number
  index_sma20: number | null
  index_sma50: number | null
  index_sma200: number | null
  index_trend: IndexTrend
  market_turnover: number
  advancing_stocks: number
  declining_stocks: number
  unchanged_stocks: number
  advance_decline_ratio: number
  market_breadth_pct: number
  breadth_rating: "strong" | "neutral" | "weak"
  total_stocks_audited: number
  pct_stocks_above_sma50: number
  pct_stocks_above_sma200: number
  index_history: IndexHistoryPoint[]
  sectors: SectorOverviewRow[]
}

export type ScreenerScoreComponent = {
  component: string
  label: string
  score: number
  max: number
}

export type ScreenerRow = {
  symbol: string
  sector: string
  current_price: number
  change_percent: number
  volume: number
  vcp_score: number
  price_action_state: string
  trend_state: TrendState
  liquidity_rating: LiquidityRating
  pivot: number | null
  distance_to_pivot: number | null
  is_pivot_near: boolean
  setup_state: SetupState
  market_regime: MarketRegime
}

/** GET /screener */
export type ScreenerResponse = {
  traded_on: string | null
  market_regime: MarketRegime
  sectors: string[]
  results: ScreenerRow[]
}

export type Contraction = {
  name: string
  high: number
  low: number
  range: number
  depth_pct: number
  volume: number
  start_date: string
  end_date: string
}

export type Candle = {
  traded_on: string
  open: number
  high: number
  low: number
  close: number
  volume: number
  sma_20: number | null
  sma_50: number | null
  sma_200: number | null
}

export type PriceLevel = {
  level: number
  touch_count: number
  anchor_dates: string[]
  type: "support" | "resistance"
  pct_distance: number
}

export type SwingPoint = { price: number; traded_on: string; index: number }

/** GET /screener/:symbol */
export type StockAnalysis = {
  symbol: string
  name: string | null
  sector: string
  current_price: number
  change_percent: number
  setup_state: SetupState
  vcp: {
    is_vcp_setup: boolean
    setup_quality_score: number
    classification: string
    base_high: number | null
    base_low: number | null
    base_duration_bars: number | null
    contractions_count: number
    contractions: Contraction[]
    contraction_sequence_text: string | null
    volume_behavior: string | null
    pivot_level: number | null
    distance_to_pivot_pct: number | null
    above_sma50: boolean | null
    above_sma200: boolean | null
  }
  vcp_breakdown: ScreenerScoreComponent[]
  price_action: {
    trend: TrendState
    structure: string
    swing_highs: SwingPoint[]
    swing_lows: SwingPoint[]
    support_levels: PriceLevel[]
    resistance_levels: PriceLevel[]
    breakout_level: number | null
    distance_to_breakout: number | null
    confidence: number
  }
  candles: Candle[]
  market: {
    regime_status: MarketRegime
    index_trend: IndexTrend
    market_breadth_pct: number
  }
  sector_context: {
    name: string
    sector_performance_pct: number
    sector_trend: TrendState
    relative_strength_rating: "strong" | "neutral" | "weak"
  } | null
}
