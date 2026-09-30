import type { Guard, ZoneState } from "../screener/types"
import type { AlertKind, SetupType } from "../watchlist/types"

export type DigestSection = "market" | "entry_zone" | "watchlist"

export type DigestSectorMove = { sector: string; change_pct: number }

export type DigestContent = {
  traded_on: string
  previous_session: string | null
  market?: {
    /** The NEPSE session the index figures come from (can trail the snapshot by a day). */
    index_on: string | null
    nepse_index: number
    index_change_pct: number
    regime: "strong" | "neutral" | "weak"
    advancing: number
    declining: number
    unchanged: number
    breadth_pct: number
    best_sectors: DigestSectorMove[]
    worst_sectors: DigestSectorMove[]
  }
  entry_zone?: {
    count: number
    joined: Array<{
      symbol: string
      name: string
      sector: string
      readiness: number
      setup_type: SetupType | null
      close: number
      entry_zone_low: number | null
      entry_zone_high: number | null
    }>
    left: Array<{ symbol: string; zone_state: ZoneState; readiness: number; guards: Guard[] }>
    held_back: Array<{ symbol: string; guards: Guard[] }>
  }
  watchlist?: {
    tracked: number
    verdicts: Array<{ symbol: string; setup_type: SetupType; state: string; close: number | null }>
    alerts: Array<{ symbol: string; kind: AlertKind; message: string }>
    book_closes: Array<{ symbol: string; book_close_on: string; days_until: number; bonus_percent: number | null; cash_percent: number | null }>
  }
}

export type DigestSummary = { id: number; traded_on: string; read_at: string | null; headline: string }

export type Digest = DigestSummary & { content: DigestContent }

export type DigestList = { unread_count: number; digests: DigestSummary[] }

export type DigestPreferences = { enabled: boolean; sections: DigestSection[]; available_sections: DigestSection[] }
