export type EventImpact = "positive" | "negative" | "mixed" | "neutral"
export type EventKind =
  | "bonus" | "cash_dividend" | "rights" | "book_close" | "results" | "agm" | "merger" | "promoter_sale" | "promoter_lockin"
  | "issue" | "regulatory" | "credit_rating" | "management" | "other"

export type MarketEvent = {
  id: number
  symbol: string | null
  company: string | null
  sector: string | null
  /** On the user's watchlist, positions, scanner radar or Strategy Lab list. */
  mine: boolean
  kind: EventKind
  impact: EventImpact
  reason: string
  important: boolean
  title: string
  url: string | null
  source: "sharesansar" | "chukul_bonus" | "chukul_rights"
  published_on: string
  /** Book close (or other dated event). */
  event_on: string | null
  data: Record<string, unknown>
}

export type BookCloseGroup = {
  key: string
  label: string
  count: number
  run_up_avg?: number | null
  run_up_up_pct?: number
  run_up_excess?: number | null
  after_avg?: number | null
  after_up_pct?: number
  after_excess?: number | null
}

/** GET /market_events */
export type MarketEventsResponse = {
  as_of: string
  /** The announcement dates the list covers. */
  from: string
  to: string
  pagination: { page: number; per: number; total: number; pages: number }
  events: MarketEvent[]
  upcoming: MarketEvent[]
  study: { window: number; from?: string; events: number; groups: BookCloseGroup[]; all: Omit<BookCloseGroup, "key" | "label"> }
}

/** from / to: announcement dates (yyyy-mm-dd, "" = default); q: symbol or company name. */
export type MarketEventFilters = { scope: "all" | "mine"; impact: EventImpact | ""; kind: EventKind | ""; from: string; to: string; q: string; page: number }
