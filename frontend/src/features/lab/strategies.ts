import type { LabStrategyKey } from "./types"

export const STRATEGY_HELP: Record<LabStrategyKey, { label: string; rule: string; exit: string }> = {
  rsi_reversion: {
    label: "RSI mean reversion",
    rule: "Price above its 200-day average; RSI(14) was under 30 in the last 3 sessions and turned up today on a higher close.",
    exit: "Stop under the 5-session low (max 8%), target 2× the risk, or the close once RSI reaches 65, or after 20 sessions.",
  },
  range_grid: {
    label: "Range (grid) bounce",
    rule: "The last 60 sessions moved in an 8–30% range with a flat 50-day average; today closed in the bottom 20% of it, up on the day.",
    exit: "Stop 3% under the range low (max 8%), target near the top of the range, or after 30 sessions.",
  },
}
