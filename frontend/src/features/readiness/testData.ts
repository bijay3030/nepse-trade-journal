import type { ReadinessSnapshot } from "../screener/types"

export function readinessSnapshot(overrides: Partial<ReadinessSnapshot> = {}): ReadinessSnapshot {
  return {
    traded_on: "2026-09-28",
    setup_type: "vcp",
    zone_state: "in_zone",
    in_buy_zone: true,
    readiness_score: 68,
    readiness_components: {
      trend: { points: 31, max: 35 },
      setup: { points: 14, max: 30 },
      market: { points: 3, max: 15 },
      sector: { points: 20, max: 20 },
      sector_vs_nepse: 3.95,
    },
    trend_rules_passed: 6,
    trend_checks: [
      { key: "above_long_mas", label: "Price above the 150- and 200-day averages", passed: true, detail: "224.90 vs 215.78 / 207.50" },
      { key: "ma200_rising", label: "200-day average rising for a month", passed: false, detail: "209.10 -> 207.50" },
      { key: "rs_rating", label: "Relative strength 70 or higher", passed: true, detail: "RS 87" },
    ],
    rs_rating: 87,
    setup_quality: 45,
    close_price: 224.9,
    entry_zone_low: 221,
    entry_zone_high: 227.63,
    invalidation_price: 207.1,
    target_price: 250,
    pivot_price: 221,
    distance_to_zone_pct: -1.73,
    ...overrides,
  }
}
