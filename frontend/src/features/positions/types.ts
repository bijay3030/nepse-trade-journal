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
}

export type BuyInput = { watchlist_item_id?: number; symbol?: string; price: number; quantity: number; traded_on: string }
