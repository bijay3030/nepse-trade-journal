export type CrossoverSignal = "ema_9_21" | "ema_21_50" | "ema_stack" | "hma_up" | "alma_cross" | "aroon_cross" | "aroon_strong"

export type ScanRow = {
  symbol: string
  name: string
  sector: string
  close: number
  change_pct: number | null
  /** Sessions since each signal began (0 = latest session), or null when it doesn't hold. */
  signals: Record<CrossoverSignal, number | null>
  values: { ema9: number | null; ema21: number | null; ema50: number | null; hma: number | null; alma: number | null; aroon_up: number | null; aroon_down: number | null }
  readiness?: number | null
  in_buy_zone?: boolean | null
  guards?: string[] | null
  avg_turnover?: number | null
}

export type SignalStats = { n: number; avg_return_pct?: number; median_return_pct?: number; win_rate_pct?: number; avg_excess_pct?: number | null }

/** GET /scans/crossovers */
export type CrossoverScan = {
  as_of: string | null
  params: { ema: number[]; hma: number; alma: { length: number; offset: number; sigma: number }; aroon: number }
  strong_aroon: number
  rows: ScanRow[]
  backtest: {
    period: { from: string | null; to: string | null }
    horizons: number[]
    signals: Record<"all" | CrossoverSignal, Record<string, SignalStats>>
  }
}

export type SignalEpisode = {
  start_on: string
  start_price: number
  end_on: string | null
  end_price: number | null
  sessions: number
  change_pct: number
  /** Still holds at the latest session. */
  open: boolean
}

export type IndicatorLine = Array<number | null>

/** GET /scans/crossovers/:symbol */
export type CrossoverChart = {
  symbol: string
  name: string
  sector: string
  params: CrossoverScan["params"]
  strong_aroon: number
  candles: Array<{ traded_on: string; open: number; high: number; low: number; close: number; volume: number }>
  lines: Record<"ema9" | "ema21" | "ema50" | "hma" | "alma" | "aroon_up" | "aroon_down", IndicatorLine>
  episodes: Record<CrossoverSignal, SignalEpisode[]>
  signals: Record<CrossoverSignal, number | null>
}

/** GET/PUT /scans/alert: the filter Telegram messages are sent for (empty = off). */
export type ScannerAlert = { signals: CrossoverSignal[]; telegram_linked: boolean }
