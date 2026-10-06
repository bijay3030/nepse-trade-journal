export type CostBreakdown = { amount: number; commission: number; sebon: number; dp: number; total: number }

/** Costs and outcomes of buying `quantity` shares (Positions::Sizer.details). */
export type SizeDetails = {
  quantity: number
  amount: number
  buy_costs: CostBreakdown
  total_cost: number
  loss_at_stop: number
  loss_pct_of_capital: number | null
  break_even: number | null
  gain_at_target: number | null
  reward_risk: number | null
}

/** Outside an uptrend: the size at a share of the usual risk, shown alongside (User#size_position). */
export type CautiousSize = { state: "under_pressure" | "correction"; label: string; size_factor: number; risk_budget: number; quantity: number }

type SizingBase = { risk_budget: number; lot_size: number; limited_by: "risk" | "capital"; cautious?: CautiousSize }

/** A suggested size; `note` (and no details) when not even one lot fits the risk budget. */
export type SizedResult = SizingBase & SizeDetails
export type UnsizedResult = SizingBase & { quantity: 0; note: string }

/** GET /position_sizing and WatchlistItem.sizing. */
export type Sizing = { error: string } | SizedResult | UnsizedResult

export function isSized(sizing: Sizing): sizing is SizedResult {
  return "buy_costs" in sizing
}

export type WatchlistSizing = Sizing & { entry?: number; stop?: number }

export type SizingResponse = Sizing & { for_quantity?: SizeDetails }

export type TradingSettings = { trading_capital: number | null; risk_per_trade_pct: number; max_open_risk_pct: number }
