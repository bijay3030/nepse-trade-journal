export type CrossoverSignal = "ema_9_21" | "ema_stack" | "hma_up" | "alma_cross" | "aroon_cross" | "aroon_strong"

export type ScanRow = {
  symbol: string
  name: string
  sector: string
  close: number
  change_pct: number | null
  /** Sessions since each signal began (0 = latest session), or null when it doesn't hold. */
  signals: Record<CrossoverSignal, number | null>
  /** The signal day's volume ÷ the previous 50 sessions' average, per signal that holds. */
  signal_volume?: Partial<Record<CrossoverSignal, number | null>>
  values: { ema9: number | null; ema21: number | null; ema50: number | null; hma: number | null; alma: number | null; aroon_up: number | null; aroon_down: number | null }
  /** Entry / stop / target: the snapshot setup's ("board_setup") or the crossover rule's. */
  levels?: RowLevels | null
  readiness?: number | null
  in_buy_zone?: boolean | null
  guards?: string[] | null
  avg_turnover?: number | null
}

export type RowLevels = {
  entry_low: number
  entry_high: number
  stop: number
  target: number | null
  source: "board_setup" | "crossover"
  setup_type: string | null
}

/** Trades with the crossover levels after each time a signal began (Scans::CrossoverBacktest). */
export type TradeStats = {
  closed: number
  skipped: number
  win_rate_pct?: number
  avg_return_pct?: number
  avg_r?: number
  profit_factor?: number | null
  exits?: Record<string, number>
}

export type SignalStats = { n: number; avg_return_pct?: number; win_rate_pct?: number }

/** GET /scans/crossovers */
export type CrossoverScan = {
  as_of: string | null
  params: { ema: number[]; hma: number; alma: { length: number; offset: number; sigma: number }; aroon: number }
  strong_aroon: number
  rows: ScanRow[]
  /** NEPSE's trend phase on the latest session (Scans::MarketPhase). */
  market_phase?: MarketPhase
  backtest: {
    period: { from: string | null; to: string | null }
    horizons: number[]
    /** The horizon by_year is measured over. */
    year_horizon: number
    /** Volume multiple for signals_with_volume. */
    strong_volume: number
    signals: Record<"all" | CrossoverSignal, Record<string, SignalStats>>
    /** The same samples, only signals that began on strong_volume x average volume. */
    signals_with_volume?: Record<CrossoverSignal, Record<string, SignalStats>>
    by_year?: Record<"all" | CrossoverSignal, Record<string, SignalStats>>
    /** 20-session results by NEPSE's phase on the signal day. */
    by_phase?: Record<"all" | CrossoverSignal, Partial<Record<MarketPhaseName, SignalStats>>>
    trades?: Record<CrossoverSignal, TradeStats>
    trade_rules?: { max_hold: number; cost_pct: number; reward_multiple: number; max_stop_pct: number }
  }
}

export type MarketPhaseName = "uptrend" | "sideways" | "downtrend"

export type MarketPhase = {
  phase: MarketPhaseName | null
  as_of?: string
  /** Sessions the phase has lasted. */
  sessions?: number
  sma20?: number
  sma50?: number | null
  band_pct?: number
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
/** volume: only send matches whose newest signal began on 1.5x average volume. */
export type ScannerAlert = { signals: CrossoverSignal[]; volume: boolean; telegram_linked: boolean; /** Live messages when a match trades in its entry zone (Settings). */ entry_alerts?: boolean }
