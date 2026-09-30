import type { DigestSection } from "./types"

export const SECTION_LABELS: Record<DigestSection, string> = {
  market: "Market summary",
  entry_zone: "Entry zone changes",
  watchlist: "Watchlist status",
}

export const SECTION_HELP: Record<DigestSection, string> = {
  market: "NEPSE close and change, regime, breadth, best and worst sectors",
  entry_zone: "Stocks that joined or left Entry zone now, and charts held back by the guards",
  watchlist: "End-of-day verdicts, the session's alerts and book closes within 10 days",
}

// Watchlist::CloseEvaluator states.
export const CLOSE_STATE_LABELS: Record<string, string> = {
  confirmed: "Breakout confirmed",
  unconfirmed: "Breakout on low volume",
  failed: "Breakout failed",
  held_zone: "Held the zone",
  in_zone: "Closed in the zone",
  below_zone: "Closed below the zone",
  above_zone: "Closed above the zone",
  invalidated: "Invalidated",
}

export const CLOSE_STATE_TONE: Record<string, "neutral" | "gain" | "loss"> = {
  confirmed: "gain",
  held_zone: "gain",
  in_zone: "gain",
  failed: "loss",
  invalidated: "loss",
}
