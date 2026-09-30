import {
  BaselineSeries,
  CandlestickSeries,
  HistogramSeries,
  LineSeries,
  LineStyle,
  createChart,
  createSeriesMarkers,
  type SeriesMarker,
  type Time,
} from "lightweight-charts"
import { useEffect, useRef } from "react"

import type { Candle, Contraction } from "../screener/types"

export type ChartLevels = {
  entryLow: number | null
  entryHigh: number | null
  invalidation: number | null
  target: number | null
  pivot: number | null
}

const NO_CONTRACTIONS: Contraction[] = []

const COLORS = {
  up: "#18745a",
  down: "#d64545",
  zone: "rgba(24, 116, 90, 0.16)",
  invalidation: "#d64545",
  target: "#18745a",
  pivot: "#ff6b2c",
  sma50: "#1f2d42",
  sma200: "#8b5cf6",
}

/**
 * Pass memoised `levels` and `contractions`: the chart is rebuilt when they change.
 *
 * Daily candles with volume, the 50- and 200-day averages, the entry zone as a
 * shaded band, invalidation / target / pivot lines, and contraction markers.
 */
export function CandlestickChart({
  candles,
  levels,
  contractions = NO_CONTRACTIONS,
  addedOn,
  height = 380,
}: {
  candles: Candle[]
  levels?: ChartLevels
  contractions?: Contraction[]
  addedOn?: string
  height?: number
}) {
  const container = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!container.current || candles.length === 0) return

    const chart = createChart(container.current, {
      autoSize: true,
      layout: { background: { color: "transparent" }, textColor: "#1f2d42", fontSize: 12 },
      grid: { vertLines: { color: "#eef2f7" }, horzLines: { color: "#eef2f7" } },
      rightPriceScale: { borderColor: "#d9e0ea" },
      timeScale: { borderColor: "#d9e0ea" },
      crosshair: { mode: 0 },
    })

    const times = candles.map((candle) => candle.traded_on as Time)

    // Entry zone: a flat baseline at the zone high, filled down to the zone low.
    if (levels?.entryLow && levels.entryHigh) {
      const band = chart.addSeries(BaselineSeries, {
        baseValue: { type: "price", price: levels.entryLow },
        topFillColor1: COLORS.zone,
        topFillColor2: COLORS.zone,
        topLineColor: "rgba(24, 116, 90, 0.5)",
        bottomFillColor1: "transparent",
        bottomFillColor2: "transparent",
        bottomLineColor: "transparent",
        lineWidth: 1,
        lastValueVisible: false,
        priceLineVisible: false,
        crosshairMarkerVisible: false,
      })
      band.setData(times.map((time) => ({ time, value: levels.entryHigh as number })))
    }

    const price = chart.addSeries(CandlestickSeries, {
      upColor: COLORS.up,
      downColor: COLORS.down,
      borderVisible: false,
      wickUpColor: COLORS.up,
      wickDownColor: COLORS.down,
    })
    price.setData(candles.map((candle) => ({ time: candle.traded_on as Time, open: candle.open, high: candle.high, low: candle.low, close: candle.close })))

    const volume = chart.addSeries(HistogramSeries, { priceScaleId: "volume", priceFormat: { type: "volume" }, lastValueVisible: false, priceLineVisible: false })
    chart.priceScale("volume").applyOptions({ scaleMargins: { top: 0.8, bottom: 0 } })
    volume.setData(
      candles.map((candle) => ({
        time: candle.traded_on as Time,
        value: candle.volume,
        color: candle.close >= candle.open ? "rgba(24, 116, 90, 0.35)" : "rgba(214, 69, 69, 0.35)",
      })),
    )

    for (const [key, color] of [["sma_50", COLORS.sma50], ["sma_200", COLORS.sma200]] as const) {
      const line = chart.addSeries(LineSeries, { color, lineWidth: 1, lastValueVisible: false, priceLineVisible: false, crosshairMarkerVisible: false })
      line.setData(candles.filter((candle) => candle[key] !== null).map((candle) => ({ time: candle.traded_on as Time, value: candle[key] as number })))
    }

    const priceLine = (value: number | null | undefined, title: string, color: string, lineStyle: LineStyle) => {
      if (value) price.createPriceLine({ price: value, color, lineWidth: 1, lineStyle, axisLabelVisible: true, title })
    }
    priceLine(levels?.invalidation, "Invalidation", COLORS.invalidation, LineStyle.Dashed)
    priceLine(levels?.target, "Target", COLORS.target, LineStyle.Solid)
    priceLine(levels?.pivot, "Pivot", COLORS.pivot, LineStyle.Dotted)

    const firstDay = candles[0].traded_on
    const markers: SeriesMarker<Time>[] = contractions
      .filter((contraction) => contraction.start_date >= firstDay)
      .map((contraction) => ({
        time: contraction.start_date as Time,
        position: "aboveBar",
        shape: "arrowDown",
        color: "#534ab7",
        // Name only: contractions often sit close together and longer labels overlap.
        // Depths are listed in the Volatility Contraction card.
        text: contraction.name,
      }))
    const addedCandle = addedOn ? candles.find((candle) => candle.traded_on >= addedOn) : undefined
    if (addedCandle) markers.push({ time: addedCandle.traded_on as Time, position: "belowBar", shape: "circle", color: "#64748b", text: "Added" })
    createSeriesMarkers(price, markers.sort((a, b) => String(a.time).localeCompare(String(b.time))))

    chart.timeScale().fitContent()
    return () => chart.remove()
  }, [candles, levels, contractions, addedOn])

  return (
    <div>
      <div ref={container} style={{ height }} data-testid="candlestick-chart" />
      <ul className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-slate" aria-label="Chart legend">
        {levels?.entryLow && levels.entryHigh ? <li><span className="mr-1 inline-block h-2.5 w-4 rounded-sm bg-pine/25 align-middle" />Entry zone</li> : null}
        {levels?.invalidation ? <li><span className="mr-1 inline-block h-0.5 w-4 border-t border-dashed border-ember align-middle" />Invalidation</li> : null}
        {levels?.target ? <li><span className="mr-1 inline-block h-0.5 w-4 bg-pine align-middle" />Target</li> : null}
        {levels?.pivot ? <li><span className="mr-1 inline-block h-0.5 w-4 border-t border-dotted border-[#ff6b2c] align-middle" />Pivot</li> : null}
        <li><span className="mr-1 inline-block h-0.5 w-4 bg-ink align-middle" />50-day</li>
        <li><span className="mr-1 inline-block h-0.5 w-4 bg-[#8b5cf6] align-middle" />200-day</li>
        {contractions.length > 0 && <li>▼ T1, T2… where each contraction starts</li>}
      </ul>
    </div>
  )
}
