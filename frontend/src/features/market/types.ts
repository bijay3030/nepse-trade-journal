export type HeatmapStock = {
  symbol: string
  name: string
  last_price: number
  change_percent: number
  market_cap: number
}

export type HeatmapSector = {
  sector: string
  market_cap: number
  /** Market-cap weighted day change. */
  change_percent: number
  advancing: number
  declining: number
  stocks: HeatmapStock[]
}

/** GET /market/heatmap */
export type MarketHeatmapResponse = {
  as_of: string | null
  stocks: number
  /** Active equities without a price or market cap, not shown. */
  unsized: number
  sectors: HeatmapSector[]
}
