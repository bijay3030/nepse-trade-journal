import type { WatchlistSizing } from "../sizing/types"
import type { BookClose, LevelAdjustment } from "../corporate/types"

export type SetupType = "vcp" | "pullback" | "ma_pullback" | "base_breakout"
export type WatchlistStatus = "watching" | "in_zone" | "extended" | "invalidated" | "planned" | "holding" | "archived"
export type PriceState = "below_zone" | "in_zone" | "extended" | "invalidated"
export type AlertKind =
  | "entered_zone"
  | "breakout_confirmed"
  | "breakout_low_volume"
  | "extended"
  | "invalidated"
  | "close_confirmed"
  | "close_unconfirmed"
  | "close_failed"
  | "close_in_zone"
  | "book_close_soon"
  | "levels_adjusted"

export type CheckStatus = "pass" | "fail" | "pending" | "n/a"

export type ChecklistItem = { key: string; label: string; status: CheckStatus; detail: string | null }

export type EntryChecklist = { checks: ChecklistItem[]; passed: number; total: number; all_passed: boolean }

export type WatchlistLevels = {
  entry_zone_low: number
  entry_zone_high: number
  invalidation_price: number
  stop_loss_price: number | null
  target_price: number | null
  pivot_price: number | null
}

export type SetupSnapshot = {
  analysed_on?: string
  price?: number
  setup_state?: string
  vcp_score?: number
  is_vcp_setup?: boolean
  contractions_count?: number
  contraction_sequence?: string | null
  volume_behavior?: string | null
  pivot?: number | null
  trend?: string
  structure?: string
  nearest_support?: number | null
  nearest_resistance?: number | null
  market_regime?: string
}

export type WatchlistItem = WatchlistLevels & {
  id: number
  symbol: string
  name: string
  sector: string
  setup_type: SetupType
  status: WatchlistStatus
  price_state: PriceState | null
  price_at_add: number | null
  current_price: number
  change_percent: number
  price_updated_at: string | null
  distance_to_zone_pct: number | null
  risk_reward: number | null
  setup_snapshot: SetupSnapshot
  notes: string | null
  trade_plan_id: number | null
  last_evaluated_at: string | null
  created_at: string
  last_close_on: string | null
  last_close_state: string | null
  last_close_price: number | null
  last_close_relative_volume: number | null
  checklist: EntryChecklist
  next_book_close?: BookClose | null
  level_adjustments?: LevelAdjustment[]
  /** The open position when the stock has been bought. */
  position_id?: number | null
  /** Position size for buying now; null until trading capital is set. */
  sizing?: WatchlistSizing | null
}

export type Suggestion =
  | {
      success: true
      symbol: string
      current_price: number
      setup_type: SetupType
      levels: WatchlistLevels & { target_basis: string }
      snapshot: SetupSnapshot
      /** For MA pullbacks and flat-base breakouts. */
      pattern?: { quality: number; details: Record<string, string | number | boolean | null> } | null
    }
  | { success: false; symbol: string; current_price: number; error: string }

export type WatchlistAlert = {
  id: number
  watchlist_item_id: number
  symbol: string
  kind: AlertKind
  message: string
  price: number | null
  relative_volume: number | null
  read_at: string | null
  created_at: string
}

export type AlertsResponse = { unread_count: number; alerts: WatchlistAlert[] }

export type LevelInput = Partial<Record<keyof WatchlistLevels, number | null>>
