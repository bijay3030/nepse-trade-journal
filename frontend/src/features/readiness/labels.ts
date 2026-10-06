import type { FlowState, Guard, ZoneState } from "../screener/types"

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
  three_weeks_tight: "3-weeks-tight",
  undercut_rally: "Undercut and rally",
} as const

export const COMPONENT_LABELS = {
  trend: "Trend template",
  rs: "RS rating",
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

export const GUARD_LABELS: Record<Guard, string> = {
  thin_volume: "Thin volume",
  upper_circuit: "At upper circuit",
  lower_circuit: "At lower circuit",
  extended: "Extended",
  late_stage_base: "Late-stage base",
}

export const GUARD_DETAILS: Record<Guard, string> = {
  thin_volume: "Low average turnover: a small order can move the price and fills may be poor.",
  upper_circuit: "Closed near the day's upper price limit (+15%): few sellers, and the next open often gaps. Wait for another session.",
  lower_circuit: "Closed near the day's lower price limit (-15%): few buyers, so exits and stops may not fill.",
  extended: "4+ ADR above the 50-day average: in the backtest, stocks this stretched usually pulled back first.",
  late_stage_base: "The 3rd or later base since the low: in the backtest, each later base did worse (20 sessions on: -1.6%, -3.1%, -4.2%).",
}

/** "NPR 34.1M" for a turnover in rupees. */
export function formatTurnover(value: number) {
  return `NPR ${(value / 1_000_000).toFixed(1)}M`
}

/** Colour band for a 0-100 readiness score. */
export function readinessTone(score: number) {
  if (score >= 60) return { stroke: "#18745a", text: "text-pine", label: "High" }
  if (score >= 40) return { stroke: "#b7791f", text: "text-amber-700", label: "Building" }
  return { stroke: "#94a3b8", text: "text-slate", label: "Low" }
}
