import type { Digest } from "./types"

export function digestFixture(overrides: Partial<Digest> = {}): Digest {
  return {
    id: 1,
    traded_on: "2026-09-29",
    read_at: null,
    headline: "1 new in the entry zone · 1 watchlist alert · NEPSE -0.91%",
    content: {
      traded_on: "2026-09-29",
      previous_session: "2026-09-28",
      market: {
        index_on: "2026-09-28", nepse_index: 2605.79, index_change_pct: -0.91, regime: "weak", advancing: 48, declining: 225, unchanged: 8,
        breadth_pct: 17.08,
        best_sectors: [{ sector: "Tradings", change_pct: 0.24 }],
        worst_sectors: [{ sector: "Investment", change_pct: -3.32 }],
      },
      entry_zone: {
        count: 3,
        joined: [{ symbol: "KBL", name: "Kumari Bank", sector: "Commercial Banks", readiness: 69, setup_type: "vcp", close: 224, entry_zone_low: 221, entry_zone_high: 227.63 }],
        left: [{ symbol: "SANIMA", zone_state: "too_early", readiness: 71, guards: [] }, { symbol: "THIN", zone_state: "in_zone", readiness: 65, guards: ["thin_volume"] }],
        held_back: [{ symbol: "JUMP", guards: ["upper_circuit"] }],
      },
      watchlist: {
        tracked: 2,
        verdicts: [{ symbol: "NABIL", setup_type: "vcp", state: "held_zone", close: 566 }],
        alerts: [{ symbol: "NABIL", kind: "entered_zone", message: "NABIL entered its entry zone at 560" }],
        book_closes: [{ symbol: "AHPC", book_close_on: "2026-10-03", days_until: 4, bonus_percent: 5, cash_percent: null }],
      },
    },
    ...overrides,
  }
}
