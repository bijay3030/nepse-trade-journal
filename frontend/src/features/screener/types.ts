import type { BookClose, DividendRow } from "../corporate/types"

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
  /** Present when the screener is served from the nightly snapshots. */
  readiness_score?: number
  zone_state?: ZoneState
  in_buy_zone?: boolean
  rs_rating?: number | null
  trend_rules_passed?: number
  setup_type?: "vcp" | "pullback" | "ma_pullback" | "base_breakout" | null
  entry_zone_low?: number | null
  entry_zone_high?: number | null
  invalidation_price?: number | null
  flow_state?: FlowState | null
  next_book_close?: BookClose | null
}

export type FlowState = "accumulation" | "distribution" | "neutral" | "no_data"

export type FlowBroker = {
  broker_no: string
  name: string | null
  net_quantity: number
  bought: number
  sold: number
  avg_buy_price: number | null
  avg_sell_price: number | null
  share_pct: number
}

export type FlowWindow = { sessions: number; volume: number; top_buyers_pct: number; top_sellers_pct: number; score: number }

/** GET /screener/:symbol -> broker_flow (Flows::AccumulationAnalyzer). */
export type BrokerFlow = {
  state: FlowState
  score: number | null
  /** Under NPR 20M turnover in 20 sessions: state held at neutral. */
  thin_trading?: boolean
  sessions: number
  windows: Partial<Record<"5" | "20", FlowWindow>>
  top_buyers: FlowBroker[]
  top_sellers: FlowBroker[]
  daily: Array<{ traded_on: string; top_buyers_net: number; top_sellers_net: number; volume: number }>
}

/** Where the price sits against the best setup's entry zone. */
export type ZoneState = "too_early" | "in_zone" | "extended" | "failed" | "no_setup"

export type TrendCheck = { key: string; label: string; passed: boolean; detail: string | null }

export type ReadinessComponent = { points: number; max: number }

/** Nightly snapshot for one stock (GET /screener/:symbol -> readiness, GET /screener/buy_zone). */
export type ReadinessSnapshot = {
  traded_on: string
  setup_type: "vcp" | "pullback" | "ma_pullback" | "base_breakout" | null
  zone_state: ZoneState
  in_buy_zone: boolean
  readiness_score: number
  readiness_components: {
    trend: ReadinessComponent
    setup: ReadinessComponent
    market: ReadinessComponent
    sector: ReadinessComponent
    flow?: ReadinessComponent
    sector_vs_nepse: number | null
    flow_score?: number | null
  }
  trend_rules_passed: number
  trend_checks: TrendCheck[]
  rs_rating: number | null
  setup_quality: number
  flow_state?: FlowState | null
  flow_score?: number | null
  close_price: number
  entry_zone_low: number | null
  entry_zone_high: number | null
  invalidation_price: number | null
  target_price: number | null
  pivot_price: number | null
  distance_to_zone_pct: number | null
}

/** GET /screener/buy_zone */
export type BuyZoneResponse = {
  traded_on: string | null
  criteria: { zone_state: ZoneState; min_trend_rules: number; min_readiness: number }
  results: Array<ReadinessSnapshot & { symbol: string; name: string; sector: string; next_book_close?: BookClose | null }>
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
  /** Latest nightly snapshot, or null before the first build. */
  readiness?: ReadinessSnapshot | null
  broker_flow?: BrokerFlow
  corporate_actions?: { upcoming: BookClose | null; history: DividendRow[] }
}
