import {
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

import { LINE_STYLES, SIGNAL_BY_KEY, type LineKey } from "./signals"
import type { CrossoverChart, CrossoverSignal } from "./types"

const AROON_PANE_HEIGHT = 120

/**
 * Candles with volume, the chosen indicator lines, Aroon in a lower pane, and ▲ / ▼
 * where each chosen signal began / ended. `sessions` limits the visible range.
 */
export function IndicatorChart({
  chart,
  sessions,
  lines,
  showAroon,
  signals,
  height = 420,
}: {
  chart: CrossoverChart
  sessions: number
  lines: LineKey[]
  showAroon: boolean
  signals: CrossoverSignal[]
  height?: number
}) {
  const container = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!container.current || chart.candles.length === 0) return
    const first = Math.max(chart.candles.length - sessions, 0)
    const candles = chart.candles.slice(first)
    const times = candles.map((candle) => candle.traded_on as Time)
    const from = candles[0].traded_on

    const view = createChart(container.current, {
      autoSize: true,
      layout: { background: { color: "transparent" }, textColor: "#1f2d42", fontSize: 12 },
      grid: { vertLines: { color: "#eef2f7" }, horzLines: { color: "#eef2f7" } },
      rightPriceScale: { borderColor: "#d9e0ea" },
      // Room after the last bar, so the newest markers aren't under the price labels.
      timeScale: { borderColor: "#d9e0ea", rightOffset: 4 },
      crosshair: { mode: 0 },
    })

    const price = view.addSeries(CandlestickSeries, { upColor: "#18745a", downColor: "#d64545", borderVisible: false, wickUpColor: "#18745a", wickDownColor: "#d64545" })
    price.setData(candles.map((c) => ({ time: c.traded_on as Time, open: c.open, high: c.high, low: c.low, close: c.close })))

    const volume = view.addSeries(HistogramSeries, { priceScaleId: "volume", priceFormat: { type: "volume" }, lastValueVisible: false, priceLineVisible: false })
    view.priceScale("volume").applyOptions({ scaleMargins: { top: 0.82, bottom: 0 } })
    volume.setData(candles.map((c) => ({ time: c.traded_on as Time, value: c.volume, color: c.close >= c.open ? "rgba(24,116,90,0.3)" : "rgba(214,69,69,0.3)" })))

    const plot = (values: Array<number | null>, options: Parameters<typeof view.addSeries<"Line">>[1], pane?: number) => {
      const series = view.addSeries(LineSeries, { lineWidth: 2, lastValueVisible: false, priceLineVisible: false, crosshairMarkerVisible: false, ...options }, pane)
      series.setData(values.slice(first).flatMap((value, i) => (value === null ? [] : [{ time: times[i], value }])))
      return series
    }
    // No axis titles: the toggle chips above the chart are the legend.
    for (const key of lines) plot(chart.lines[key], { color: LINE_STYLES[key].color })

    const markers: SeriesMarker<Time>[] = signals.flatMap((key) =>
      chart.episodes[key].flatMap((episode) => {
        const out: SeriesMarker<Time>[] = []
        if (episode.start_on >= from) {
          out.push({ time: episode.start_on as Time, position: "belowBar", shape: "arrowUp", color: "#18745a", text: `${SIGNAL_BY_KEY[key].short} ▲` })
        }
        if (episode.end_on && episode.end_on >= from) {
          out.push({ time: episode.end_on as Time, position: "aboveBar", shape: "arrowDown", color: "#d64545", text: `${SIGNAL_BY_KEY[key].short} ▼` })
        }
        return out
      }),
    )
    createSeriesMarkers(price, markers.sort((a, b) => String(a.time).localeCompare(String(b.time))))

    if (showAroon) {
      const up = plot(chart.lines.aroon_up, { color: "#18745a", title: "Aroon Up", lastValueVisible: true }, 1)
      plot(chart.lines.aroon_down, { color: "#d64545", title: "Aroon Down", lastValueVisible: true }, 1)
      up.createPriceLine({ price: chart.strong_aroon, color: "#94a3b8", lineWidth: 1, lineStyle: LineStyle.Dashed, axisLabelVisible: false, title: String(chart.strong_aroon) })
      view.panes()[1]?.setHeight(AROON_PANE_HEIGHT)
    }

    view.timeScale().fitContent()
    return () => view.remove()
  }, [chart, sessions, lines, showAroon, signals])

  return <div ref={container} style={{ height: height + (showAroon ? AROON_PANE_HEIGHT : 0) }} data-testid="indicator-chart" />
}
