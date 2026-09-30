import type { WatchlistItem } from "./types"

export function watchlistItem(overrides: Partial<WatchlistItem> = {}): WatchlistItem {
  return {
    id: 7,
    symbol: "NABIL",
    name: "Nabil Bank Limited",
    sector: "Commercial Banks",
    setup_type: "vcp",
    status: "watching",
    price_state: "below_zone",
    entry_zone_low: 570,
    entry_zone_high: 587.1,
    invalidation_price: 548,
    stop_loss_price: 548,
    target_price: 640,
    pivot_price: 570,
    price_at_add: 560,
    current_price: 565,
    change_percent: 0.71,
    price_updated_at: "2026-09-27T09:00:00Z",
    distance_to_zone_pct: 0.88,
    risk_reward: 3.18,
    setup_snapshot: { vcp_score: 72, contractions_count: 3, trend: "uptrend", market_regime: "bullish", analysed_on: "2026-09-24" },
    notes: "Tight T3 on drying volume",
    trade_plan_id: null,
    last_evaluated_at: "2026-09-27T09:00:00Z",
    created_at: "2026-09-27T08:00:00Z",
    ...overrides,
  }
}
