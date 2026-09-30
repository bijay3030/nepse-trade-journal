import type { AlertKind, PriceState, SetupType, WatchlistStatus } from "./types"

export const SETUP_LABELS: Record<SetupType, string> = {
  vcp: "VCP breakout",
  pullback: "Pullback to support",
  ma_pullback: "Pullback to a rising average",
  base_breakout: "Flat-base breakout",
}

export const SETUP_HELP: Record<SetupType, string> = {
  vcp: "Zone from the pivot to 3% above it. Fails below the last contraction's low.",
  pullback: "Zone from the nearest support to 2% above it. Fails 3% below support.",
  ma_pullback: "Uptrend pulling back to its rising 20- or 50-day average. Zone: the average to 2% above; fails 4% below it.",
  base_breakout: "Tight 15-60 session base near the 52-week high. Zone: base high to 3% above; fails at the base low (at most 8% down).",
}

export const STATUS_LABELS: Record<WatchlistStatus, string> = {
  watching: "Watching",
  in_zone: "In zone",
  extended: "Extended",
  invalidated: "Invalidated",
  planned: "Planned",
  archived: "Archived",
}

export const STATUS_TONE: Record<WatchlistStatus, "neutral" | "gain" | "loss"> = {
  watching: "neutral",
  in_zone: "gain",
  extended: "neutral",
  invalidated: "loss",
  planned: "gain",
  archived: "neutral",
}

export const PRICE_STATE_LABELS: Record<PriceState, string> = {
  below_zone: "Below zone",
  in_zone: "In zone",
  extended: "Above zone",
  invalidated: "Below invalidation",
}

export const ALERT_LABELS: Record<AlertKind, string> = {
  entered_zone: "Entered zone",
  breakout_confirmed: "Breakout confirmed",
  breakout_low_volume: "Breakout, low volume",
  extended: "Extended",
  invalidated: "Invalidated",
  close_confirmed: "Close confirmed",
  close_unconfirmed: "Close, low volume",
  close_failed: "Failed at close",
  close_in_zone: "Held zone at close",
}

export const ALERT_TONE: Record<AlertKind, "neutral" | "gain" | "loss"> = {
  entered_zone: "gain",
  breakout_confirmed: "gain",
  breakout_low_volume: "neutral",
  extended: "neutral",
  invalidated: "loss",
  close_confirmed: "gain",
  close_unconfirmed: "neutral",
  close_failed: "loss",
  close_in_zone: "gain",
}

export function formatPrice(value: number | null | undefined) {
  if (value === null || value === undefined || !Number.isFinite(value)) return "—"
  return value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}
