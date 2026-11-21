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
