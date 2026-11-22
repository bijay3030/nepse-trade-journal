import type { EventImpact, EventKind } from "./types"

export const KIND_LABELS: Record<EventKind, string> = {
  bonus: "Bonus", cash_dividend: "Cash dividend", rights: "Rights", book_close: "Book close", results: "Quarterly results", agm: "AGM / SGM",
  merger: "Merger", promoter_sale: "Promoter shares", promoter_lockin: "Promoter lock-in", issue: "Share issue", regulatory: "Regulatory",
  credit_rating: "Credit rating", management: "Management", other: "Other notice",
}

export const IMPACT_LOOK: Record<EventImpact, { label: string; chip: string }> = {
  positive: { label: "Good", chip: "bg-pine/15 text-pine" },
  negative: { label: "Bad", chip: "bg-ember/15 text-ember" },
  mixed: { label: "Mixed", chip: "bg-amber-100 text-amber-800" },
  neutral: { label: "Neutral", chip: "bg-slate/10 text-slate" },
}
