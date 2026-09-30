/** Next book close (dividend / bonus entitlement date) within 45 days. */
export type BookClose = {
  fiscal_year: string
  book_close_on: string
  days_until: number
  cash_percent: number | null
  bonus_percent: number | null
  agm_on: string | null
}

export type DividendRow = {
  fiscal_year: string
  cash_percent: number | null
  bonus_percent: number | null
  total_percent: number | null
  book_close_on: string | null
  agm_on: string | null
}

export type LevelAdjustment = { fiscal_year: string; bonus_percent: number; factor: number; book_close_on: string }
