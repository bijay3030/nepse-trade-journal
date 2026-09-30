import type { WatchlistLevels } from "./types"

export type LevelDraft = Record<"entry_zone_low" | "entry_zone_high" | "invalidation_price" | "stop_loss_price" | "target_price", string>

export const EMPTY_LEVELS: LevelDraft = {
  entry_zone_low: "",
  entry_zone_high: "",
  invalidation_price: "",
  stop_loss_price: "",
  target_price: "",
}

export function levelsToDraft(levels: Partial<WatchlistLevels>): LevelDraft {
  const text = (value: number | null | undefined) => (value === null || value === undefined ? "" : String(value))
  return {
    entry_zone_low: text(levels.entry_zone_low),
    entry_zone_high: text(levels.entry_zone_high),
    invalidation_price: text(levels.invalidation_price),
    stop_loss_price: text(levels.stop_loss_price),
    target_price: text(levels.target_price),
  }
}

export function draftToLevels(draft: LevelDraft) {
  const num = (value: string) => (value.trim() === "" ? null : Number(value))
  return {
    entry_zone_low: num(draft.entry_zone_low),
    entry_zone_high: num(draft.entry_zone_high),
    invalidation_price: num(draft.invalidation_price),
    stop_loss_price: num(draft.stop_loss_price),
    target_price: num(draft.target_price),
  }
}

// Mirrors the backend: reward from the zone low to the target over risk to the stop.
export function riskReward(draft: LevelDraft) {
  const { entry_zone_low: entry, stop_loss_price: stop, target_price: target, invalidation_price: invalidation } = draftToLevels(draft)
  const risk = stop ?? invalidation
  if (!entry || !risk || !target || entry <= risk) return null
  return Math.round(((target - entry) / (entry - risk)) * 100) / 100
}
