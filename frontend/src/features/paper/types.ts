export type PaperTradeRow = {
  id: number
  symbol: string
  name: string
  status: "pending" | "open" | "closed"
  trigger: "watchlist_entered_zone" | "watchlist_breakout" | "board_new"
  signal_on: string
  quantity: number
  buy_reason: string
  entry_price: number | null
  entry_at: string | null
  buy_costs: number | null
  stop_price: number
  target_price: number | null
  last_price: number
  /** First day the shares can be sold (T+2). */
  sellable_on: string | null
  unrealized_pnl: number | null
  exit_price: number | null
  exit_at: string | null
  exit_rule: string | null
  sell_reason: string | null
  sell_costs: number | null
  cgt: number | null
  net_pnl: number | null
  return_pct: number | null
  held_days: number | null
}

export type PaperLogEntry = { id: number; at: string; action: "signal" | "buy" | "skip" | "hold" | "sell"; symbol: string; price: number | null; reason: string; trade_id: number | null }

/** GET /paper_trading */
export type PaperAccount = {
  enabled: boolean
  quantity: number
  slippage_pct: number
  summary: { open: number; pending: number; closed: number; invested: number; open_pnl: number; realized_pnl: number; win_rate_pct: number | null; profit_factor: number | null }
  trades: PaperTradeRow[]
  log: PaperLogEntry[]
}
