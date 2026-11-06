import { render } from "@testing-library/react"
import { vi } from "vitest"

import { IndicatorChart } from "./IndicatorChart"
import type { CrossoverChart } from "./types"

const calls = vi.hoisted(() => ({ series: [] as Array<{ title?: unknown; pane?: number }>, markers: [] as Array<Record<string, unknown>> }))

vi.mock("lightweight-charts", () => ({
  CandlestickSeries: "Candlestick", HistogramSeries: "Histogram", LineSeries: "Line", LineStyle: { Dashed: 2 },
  createChart: () => ({
    addSeries: (_kind: string, options: Record<string, unknown>, pane?: number) => {
      calls.series.push({ title: options.title, pane })
      return { setData: vi.fn(), createPriceLine: vi.fn() }
    },
    panes: () => [{ setHeight: vi.fn() }, { setHeight: vi.fn() }],
    priceScale: () => ({ applyOptions: vi.fn() }),
    timeScale: () => ({ fitContent: vi.fn() }),
    remove: vi.fn(),
  }),
  createSeriesMarkers: (_series: unknown, markers: Array<Record<string, unknown>>) => calls.markers.push(...markers),
}))

const days = ["2026-10-01", "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07"]
const chart: CrossoverChart = {
  symbol: "NRIC", name: "NRIC Ltd", sector: "Others", params: { ema: [9, 21, 50], hma: 21, alma: { length: 9, offset: 0.85, sigma: 6 }, aroon: 25 }, strong_aroon: 70,
  candles: days.map((traded_on, i) => ({ traded_on, open: 100 + i, high: 102 + i, low: 99 + i, close: 101 + i, volume: 1000 })),
  lines: { ema9: [1, 2, 3, 4, 5], ema21: [1, 2, 3, 4, 5], ema50: [null, null, 1, 2, 3], hma: [1, 2, 3, 4, 5], alma: [1, 2, 3, 4, 5], aroon_up: [10, 20, 30, 40, 80], aroon_down: [90, 80, 70, 60, 20] },
  episodes: {
    ema_9_21: [
      { start_on: "2026-10-01", start_price: 101, end_on: "2026-10-05", end_price: 103, sessions: 2, change_pct: 1.98, open: false },
      { start_on: "2026-10-07", start_price: 105, end_on: null, end_price: null, sessions: 0, change_pct: 0, open: true },
    ],
    ema_21_50: [], ema_stack: [], hma_up: [], alma_cross: [], aroon_cross: [], aroon_strong: [],
  },
  signals: { ema_9_21: 0, ema_21_50: null, ema_stack: null, hma_up: null, alma_cross: null, aroon_cross: null, aroon_strong: null },
}

describe("IndicatorChart", () => {
  beforeEach(() => {
    calls.series = []
    calls.markers = []
  })

  it("marks where each chosen signal began (▲ below) and ended (▼ above), within the range", () => {
    render(<IndicatorChart chart={chart} sessions={4} lines={["ema9", "ema21"]} showAroon signals={["ema_9_21"]} />)

    // The 1 Oct start is outside the last 4 sessions; its 5 Oct end and the 7 Oct start are inside.
    expect(calls.markers).toEqual([
      expect.objectContaining({ time: "2026-10-05", position: "aboveBar", shape: "arrowDown", text: "9/21 ▼" }),
      expect.objectContaining({ time: "2026-10-07", position: "belowBar", shape: "arrowUp", text: "9/21 ▲" }),
    ])
  })

  it("draws only the chosen lines, and Aroon in a second pane when on", () => {
    render(<IndicatorChart chart={chart} sessions={5} lines={["ema9", "hma"]} showAroon signals={[]} />)
    // Candles, volume, 2 lines, then Aroon Up/Down in the second pane.
    expect(calls.series).toHaveLength(6)
    expect(calls.series.filter((s) => s.pane === 1).map((s) => s.title)).toEqual(["Aroon Up", "Aroon Down"])

    calls.series = []
    render(<IndicatorChart chart={chart} sessions={5} lines={[]} showAroon={false} signals={[]} />)
    expect(calls.series).toHaveLength(2) // candles and volume only
  })
})
