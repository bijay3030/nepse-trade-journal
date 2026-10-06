import type { SetupType } from "../watchlist/types"

export type PositionFill = { id: number; side: "buy" | "sell"; price: number; quantity: number; traded_on: string }

/** GET /positions, /positions/:id */
export type Position = {
  id: number
  /** The newest sell-rule alert (Positions::Monitor). */
  latest_alert?: { id: number; kind: PositionAlertKind; message: string; created_at: string; read: boolean } | null
  symbol: string
  name: string
  sector: string
  status: "open" | "closed"
  setup_type: SetupType | null
  watchlist_item_id: number | null
  quantity: number
  average_price: number
  last_price: number
  change_percent: number
  price_updated_at: string | null
  stop_price: number
  initial_stop_price: number
  target_price: number | null
  unrealized_pnl: number
  unrealized_pct: number | null
  /** Move in units of the risk at entry (average price to the first stop). */
  r_multiple: number | null
  /** Loss if the current stop is hit, after buy and sell fees; 0 once that wouldn't lose money. */
  open_risk: number
  /** What the open shares cost, including commission and SEBON fee. */
  cost_basis: number
  /** Selling everything at the last price, after sell fees (before capital gains tax). */
  net_pnl_if_sold: number
  break_even_price: number | null
  opened_on: string | null
  /** T+2: first day the newest shares can be sold (holidays not counted). */
  sellable_on: string | null
  days_held: number
  closed_on: string | null
  notes: string | null
  fills: PositionFill[]
  /** Sells so far, matched FIFO: proceeds and cost after fees, gain, CGT and net. */
  realized?: { proceeds: number; cost: number; gain: number; tax: number; net: number }
  average_sell_price?: number | null
  closed_r_multiple?: number | null
  /** Closed positions: worst / best move while held (MAE / MFE). */
  excursions?: { mae_pct?: number; mfe_pct?: number; mae_r?: number | null; mfe_r?: number | null } | null
  /** Settled (T+2) shares not yet sold. */
  settled_quantity?: number
  review?: Review
}

export type PlanFollowed = "yes" | "partly" | "no"
export type ReviewTag = "chased_entry" | "moved_stop_down" | "sold_too_early" | "held_past_stop" | "oversized" | "ignored_market"
export type Review = { plan_followed: PlanFollowed | null; tags: ReviewTag[]; lesson: string | null; reviewed_at: string | null }

export type SellInput = { price: number; quantity: number; traded_on: string }

/** GET /positions/stats (Positions::Stats). */
export type PositionStats = {
  closed: number
  win_rate_pct?: number
  net_pnl?: number
  tax_paid?: number
  avg_win?: number | null
  avg_loss?: number | null
  expectancy?: number
  avg_r?: number | null
  avg_days_held?: number
  reviewed?: number
  plan_followed_pct?: number | null
}

export type BuyInput = { watchlist_item_id?: number; symbol?: string; price: number; quantity: number; traded_on: string }

export type PositionAlertKind = "stop_hit" | "target_reached" | "one_r" | "profit_zone" | "fifty_day_break" | "climax_run" | "time_stop"

/** GET /position_alerts (Positions::Monitor). */
export type PositionAlert = {
  id: number
  position_id: number
  symbol: string
  kind: PositionAlertKind
  message: string
  price: number | null
  read_at: string | null
  created_at: string
  position_open: boolean
  stop_price: number
  /** Only on an open position's +1R alert: the stop that makes the trade risk-free after costs. */
  break_even_price: number | null
}

export type PositionAlertsResponse = { unread_count: number; alerts: PositionAlert[] }

export type HeatState = "ok" | "near" | "over" | "unknown"

/** GET /positions/portfolio (Positions::Portfolio). */
export type Portfolio = {
  capital: number | null
  open_risk: number
  market_value: number
  invested: number
  cash: number | null
  heat: { pct: number | null; limit_pct: number; state: HeatState; room: number | null }
  positions: Array<{ position_id: number; symbol: string; open_risk: number; heat_pct: number | null; share_of_risk_pct: number | null }>
  sectors: Array<{ sector: string; value: number; pct: number | null; symbols: string[]; over: boolean }>
}
