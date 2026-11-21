import { LineSeries, createChart, createSeriesMarkers, type SeriesMarker, type Time } from "lightweight-charts"
import { useEffect, useRef } from "react"

import type { StockBacktestTrade } from "./types"

const WIN = "#18745a"
const LOSS = "#d64545"

/**
 * The stock's closing price with one strategy's trades: ▲ at each buy and ▼ at each
 * sell, green when the trade made money after costs, red when it lost.
 */
export function TradesChart({ prices, trades, height = 340 }: { prices: Array<{ date: string; close: number }>; trades: StockBacktestTrade[]; height?: number }) {
  const container = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!container.current || prices.length === 0) return
    const view = createChart(container.current, {
      autoSize: true,
      layout: { background: { color: "transparent" }, textColor: "#1f2d42", fontSize: 12 },
      grid: { vertLines: { color: "#eef2f7" }, horzLines: { color: "#eef2f7" } },
      rightPriceScale: { borderColor: "#d9e0ea" },
      timeScale: { borderColor: "#d9e0ea", fixLeftEdge: true, fixRightEdge: true, minBarSpacing: 0.1 },
      crosshair: { mode: 0 },
    })
    const line = view.addSeries(LineSeries, { color: "#2563eb", lineWidth: 2, priceLineVisible: false })
    line.setData(prices.map((p) => ({ time: p.date as Time, value: p.close })))

    const markers: SeriesMarker<Time>[] = trades.flatMap((t) => {
      const color = t.return_pct > 0 ? WIN : LOSS
      const buy: SeriesMarker<Time> = { time: t.entry_on as Time, position: "belowBar", shape: "arrowUp", color }
      if (!t.exit_on) return [buy]
      const sell: SeriesMarker<Time> = { time: t.exit_on as Time, position: "aboveBar", shape: "arrowDown", color }
      return [buy, sell]
    }).sort((a, b) => String(a.time).localeCompare(String(b.time)))
    createSeriesMarkers(line, markers)
    view.timeScale().fitContent()
    // autoSize measures the box a frame later; fit again at the real width.
    const frame = requestAnimationFrame(() => view.timeScale().fitContent())
    return () => {
      cancelAnimationFrame(frame)
      view.remove()
    }
  }, [prices, trades])

  return <div ref={container} style={{ height }} className="w-full" data-testid="trades-chart" role="img" aria-label={`Closing price with ${trades.length} trades: buys and sells marked`} />
}
