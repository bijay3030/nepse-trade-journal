import type { FlowState, ZoneState } from "../screener/types"

// Neutral wording: the app never labels anything "buy" or "sell".
export const ZONE_LABELS: Record<ZoneState, string> = {
  too_early: "Too early",
  in_zone: "In entry zone",
  extended: "Extended",
  failed: "Failed",
  no_setup: "No setup",
}

export const ZONE_TONE: Record<ZoneState, "neutral" | "gain" | "loss"> = {
  too_early: "neutral",
  in_zone: "gain",
  extended: "neutral",
  failed: "loss",
  no_setup: "neutral",
}

export const SETUP_TYPE_LABELS = {
  vcp: "VCP breakout",
  pullback: "Pullback to support",
  ma_pullback: "Pullback to a rising average",
  base_breakout: "Flat-base breakout",
} as const

export const COMPONENT_LABELS = {
  trend: "Trend template",
  setup: "Setup quality",
  market: "Market regime",
  sector: "Sector vs NEPSE",
  flow: "Broker flow",
} as const

export const FLOW_LABELS: Record<FlowState, string> = {
  accumulation: "Accumulation",
  distribution: "Distribution",
  neutral: "Neutral flow",
  no_data: "No flow data",
}

export const FLOW_TONE: Record<FlowState, "neutral" | "gain" | "loss"> = {
  accumulation: "gain",
  distribution: "loss",
  neutral: "neutral",
  no_data: "neutral",
}

/** Colour band for a 0-100 readiness score. */
export function readinessTone(score: number) {
  if (score >= 60) return { stroke: "#18745a", text: "text-pine", label: "High" }
  if (score >= 40) return { stroke: "#b7791f", text: "text-amber-700", label: "Building" }
  return { stroke: "#94a3b8", text: "text-slate", label: "Low" }
}
