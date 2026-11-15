import type { CrossoverSignal } from "./types"

export const SIGNALS: Array<{ key: CrossoverSignal; label: string; short: string; help: string }> = [
  { key: "ema_9_21", label: "EMA 9 crossed above 21", short: "9/21", help: "Short-term momentum turned up: the 2-week average rose above the 1-month one." },
  { key: "ema_stack", label: "EMA 9 > 21 > 50", short: "Stack", help: "Every timeframe agrees on an uptrend (age = sessions since the stack formed)." },
  { key: "hma_up", label: "HMA 55 turned up", short: "HMA↑", help: "The 55-session Hull average (low lag) switched from falling to rising. The best balance in the 2020-2026 test." },
  { key: "alma_cross", label: "Price crossed above ALMA 21", short: "ALMA", help: "The close moved above the 21-session Arnaud Legoux average (smooth, responsive)." },
  { key: "aroon_cross", label: "Aroon Up crossed above Down", short: "Aroon×", help: "New highs became more recent than new lows: a possible new uptrend." },
  { key: "aroon_strong", label: "Aroon Up ≥ 70", short: "Aroon≥70", help: "A new 25-session high within the last 7 sessions: the uptrend is fresh." },
]

export const SIGNAL_BY_KEY = Object.fromEntries(SIGNALS.map((signal) => [signal.key, signal])) as Record<CrossoverSignal, (typeof SIGNALS)[number]>

export type LineKey = "ema9" | "ema21" | "ema50" | "hma" | "alma"

export const LINE_STYLES: Record<LineKey, { label: string; color: string }> = {
  ema9: { label: "EMA 9", color: "#f59e0b" },
  ema21: { label: "EMA 21", color: "#2563eb" },
  ema50: { label: "EMA 50", color: "#1f2d42" },
  hma: { label: "HMA 55", color: "#db2777" },
  alma: { label: "ALMA 21", color: "#0d9488" },
}

/** Volume multiple the "on strong volume" filter needs on the signal day (Scans::Crossovers::STRONG_VOLUME). */
export const STRONG_VOLUME = 1.5
