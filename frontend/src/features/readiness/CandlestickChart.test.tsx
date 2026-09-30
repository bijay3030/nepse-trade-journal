import { render } from "@testing-library/react"
import { vi } from "vitest"

import type { Candle, Contraction } from "../screener/types"
import { CandlestickChart } from "./CandlestickChart"

const calls = vi.hoisted(() => ({ series: [] as Array<{ kind: string; options: Record<string, unknown> }>, priceLines: [] as Array<Record<string, unknown>>, markers: [] as Array<Record<string, unknown>>, removed: 0 }))

vi.mock("lightweight-charts", () => {
  const series = (kind: string, options: Record<string, unknown>) => {
    calls.series.push({ kind, options })
    return { setData: vi.fn(), createPriceLine: (line: Record<string, unknown>) => calls.priceLines.push(line) }
  }
  return {
    CandlestickSeries: "Candlestick",
    HistogramSeries: "Histogram",
    LineSeries: "Line",
    BaselineSeries: "Baseline",
    LineStyle: { Solid: 0, Dotted: 1, Dashed: 2 },
    createChart: () => ({
      addSeries: (kind: string, options: Record<string, unknown>) => series(kind, options),
      priceScale: () => ({ applyOptions: vi.fn() }),
      timeScale: () => ({ fitContent: vi.fn() }),
      remove: () => { calls.removed += 1 },
    }),
    createSeriesMarkers: (_series: unknown, markers: Array<Record<string, unknown>>) => calls.markers.push(...markers),
  }
})

const candle = (day: string, close: number): Candle => ({ traded_on: day, open: close - 1, high: close + 2, low: close - 2, close, volume: 1000, sma_20: null, sma_50: close, sma_200: null })
const candles = [candle("2026-09-24", 220), candle("2026-09-25", 222), candle("2026-09-28", 225)]
const contractions: Contraction[] = [{ name: "T1", high: 240, low: 210, range: 30, depth_pct: 12.5, volume: 1, start_date: "2026-09-24", end_date: "2026-09-25" }]
const levels = { entryLow: 221, entryHigh: 227.63, invalidation: 207.1, target: 250, pivot: 221 }

describe("CandlestickChart", () => {
  beforeEach(() => {
    calls.series.length = 0
    calls.priceLines.length = 0
    calls.markers.length = 0
  })

  it("draws candles, volume, averages, the zone band, level lines and markers", () => {
    render(<CandlestickChart candles={candles} levels={levels} contractions={contractions} addedOn="2026-09-25" />)

    expect(calls.series.map((s) => s.kind)).toEqual(["Baseline", "Candlestick", "Histogram", "Line", "Line"])
    expect(calls.series[0].options.baseValue).toEqual({ type: "price", price: 221 })
    expect(calls.priceLines.map((line) => [line.title, line.price])).toEqual([["Invalidation", 207.1], ["Target", 250], ["Pivot", 221]])
    expect(calls.markers.map((marker) => marker.text)).toEqual(["T1", "Added"])
  })

  it("skips the zone band and lines without levels, and cleans up on unmount", () => {
    const { unmount } = render(<CandlestickChart candles={candles} />)

    expect(calls.series.map((s) => s.kind)).not.toContain("Baseline")
    expect(calls.priceLines).toHaveLength(0)
    const before = calls.removed
    unmount()
    expect(calls.removed).toBe(before + 1)
  })
})
