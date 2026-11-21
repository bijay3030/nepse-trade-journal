import type { MarketPhase, MarketPhaseName } from "../scanner/types"

export type LabStrategyKey = "rsi_reversion" | "range_grid"

export type LabStats = { trades: number; win_rate_pct?: number; avg_return_pct?: number; avg_r?: number; profit_factor?: number | null; max_drawdown_pct?: number }

export type LabLevels = { entry_low: number; entry_high: number; stop: number; target: number; reward_risk: number; range_low?: number; range_high?: number }

export type LabCandidate = {
  stock_id: number
  symbol: string
  name: string
  sector: string
  strategy: LabStrategyKey
  signal_on: string
  close: number
  change_pct: number | null
  rsi: number | null
  levels: LabLevels
  /** The strategy's record on this stock since 2020, with the out-of-sample part. */
  record: LabStats & { oos: LabStats }
  readiness: number | null
  guards: string[]
}

export type LabLeaderboardEntry = LabStats & {
  oos: LabStats
  by_year: Record<string, LabStats>
  by_phase: Record<MarketPhaseName, LabStats>
}

export type LabPaperTrade = {
  id: number
  symbol: string
  strategy: LabStrategyKey
  signal_on: string
  levels: LabLevels
  status: "pending" | "open" | "closed" | "skipped"
  entry_on: string | null
  entry_price: number | null
  exit_on: string | null
  exit_price: number | null
  exit_reason: string | null
  return_pct: number | null
  r_multiple: number | null
}

/** GET /lab */
export type LabReport = {
  as_of: string | null
  period: { from: string; to: string | null }
  oos_from: string
  rules: { min_trades: number; min_profit_factor: number; min_oos_trades: number; cost_pct: number }
  strategies: Array<{ key: LabStrategyKey; label: string; hold: number }>
  leaderboard: Record<LabStrategyKey, LabLeaderboardEntry>
  candidates: LabCandidate[]
  qualifying: Record<LabStrategyKey, Array<{ symbol: string; trades: number; profit_factor: number | null }>>
  market_phase?: MarketPhase
  paper_trades: {
    summary: { total: number; open: number; pending: number; skipped: number; closed: number; win_rate_pct: number | null; avg_return_pct: number | null; profit_factor: number | null }
    trades: LabPaperTrade[]
  }
}

/** GET /lab/stocks/:symbol (Lab::StockReport) */
export type StockBacktestStats = {
  trades: number
  open?: number
  win_rate_pct?: number
  profit_factor?: number | null
  avg_return_pct?: number
  total_return_pct?: number
  max_drawdown_pct?: number
  best_pct?: number
  worst_pct?: number
  avg_hold?: number
  by_year?: Record<string, { trades: number; total_return_pct: number }>
}

export type StockBacktestStrategy = {
  key: string
  label: string
  family: "Indicator Scanner" | "Classic" | "Strategy Lab"
  signals: number
  latest_signal: string | null
  sessions_since_signal: number | null
  forward20: { count: number; avg_pct: number; up_pct: number } | null
  stats: StockBacktestStats
}

/** One trade: the signal session, the buy (next open), the sell and how long it was held. */
export type StockBacktestTrade = {
  key: string
  signal_on: string
  entry_on: string
  exit_on: string | null
  entry: number
  exit: number
  return_pct: number
  reason: "stop" | "target" | "time" | "rsi_exit" | "open" | string
  open: boolean
  /** Trading sessions from the buy to the sell, both counted. */
  held_sessions: number
  held_days: number
}

export type StockBacktest = {
  symbol: string
  name: string
  sector: string
  sessions: number
  from: string
  to: string
  close: number
  rules: { hold: number; max_stop_pct: number; reward_multiple: number; cost_pct: number; max_gap_pct: number }
  buy_hold: { return_pct: number; max_drawdown_pct: number; by_year: Record<string, number> }
  baseline: { "20": { count: number; avg_pct: number; up_pct: number } | null }
  strategies: StockBacktestStrategy[]
  trades: StockBacktestTrade[]
  prices: Array<{ date: string; close: number }>
  now: {
    rsi: number | null; sma50: number | null; sma200: number | null; macd: number | null; macd_signal: number | null; bb_lower: number | null
    high_52w: number; low_52w: number
    levels: { entry_low: number; entry_high: number; stop: number; target: number | null; source: "board_setup" | "crossover"; setup_type: string | null } | null
    readiness: number | null; trend_rules_passed: number | null; rs_rating: number | null; in_buy_zone: boolean | null
  }
}
