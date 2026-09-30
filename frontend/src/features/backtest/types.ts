export type Horizon = "5" | "10" | "20"

export type HorizonStats = {
  n: number
  avg_return_pct?: number
  median_return_pct?: number
  win_rate_pct?: number
  avg_excess_pct?: number | null
}

export type GroupStats = Record<Horizon, HorizonStats>

export type BacktestTrade = {
  symbol: string
  signal_on: string
  entry_on: string
  entry: number
  stop: number
  target: number
  status: "closed" | "open" | "skipped"
  exit_on?: string
  exit?: number
  exit_reason?: "stop" | "target" | "time"
  return_pct?: number
  r_multiple?: number
  sessions_held?: number
}

export type BacktestResults = {
  period: { from: string; to: string; sessions: number; snapshots: number; stocks: number }
  baseline: GroupStats
  groups: {
    readiness: Record<string, GroupStats>
    zone_state: Record<string, GroupStats>
    flow_state: Record<string, GroupStats>
    trend: Record<string, GroupStats>
    setup_type?: Record<string, GroupStats>
    entry_zone: Record<string, GroupStats>
  }
  trades: {
    total: number
    closed: number
    open: number
    /** Entries less than min_risk_pct above the stop, not traded. */
    skipped?: number
    min_risk_pct?: number
    win_rate_pct: number | null
    avg_return_pct: number | null
    avg_r: number | null
    median_r?: number | null
    avg_win_pct: number | null
    avg_loss_pct: number | null
    profit_factor: number | null
    avg_sessions_held: number | null
    exits: Partial<Record<"stop" | "target" | "time", number>>
    by_setup_type?: Record<string, { closed: number; win_rate_pct: number; avg_return_pct: number }>
    list: BacktestTrade[]
  }
}

/** GET /backtest */
export type BacktestRun = {
  id: number
  created_at: string
  from_date: string
  to_date: string
  sessions: number
  parameters: { horizons: number[]; max_hold: number; round_trip_cost_pct: number; readiness_bands: string[] }
  results: BacktestResults
}
