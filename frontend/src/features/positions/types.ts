import type { SetupType } from "../watchlist/types"

export type PositionFill = { id: number; side: "buy" | "sell"; price: number; quantity: number; traded_on: string }

/** GET /positions, /positions/:id */
export type Position = {
  id: number
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
  /** Loss if the current stop is hit; 0 once the stop is at or above the average. */
  open_risk: number
  opened_on: string | null
  /** T+2: first day the newest shares can be sold (holidays not counted). */
  sellable_on: string | null
  days_held: number
  closed_on: string | null
  notes: string | null
  fills: PositionFill[]
}

export type BuyInput = { watchlist_item_id?: number; symbol?: string; price: number; quantity: number; traded_on: string }
