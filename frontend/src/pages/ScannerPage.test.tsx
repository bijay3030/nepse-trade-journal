import { screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import type { CrossoverScan, ScanRow } from "../features/scanner/types"
import { renderWithClient } from "../test/renderWithClient"
import { ScannerPage } from "./ScannerPage"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet } }))
vi.mock("lightweight-charts", () => {
  const series = { setData: vi.fn(), createPriceLine: vi.fn() }
  return {
    CandlestickSeries: "Candlestick", HistogramSeries: "Histogram", LineSeries: "Line", LineStyle: { Dashed: 2 },
    createChart: () => ({ addSeries: () => series, panes: () => [{ setHeight: vi.fn() }, { setHeight: vi.fn() }], priceScale: () => ({ applyOptions: vi.fn() }), timeScale: () => ({ fitContent: vi.fn() }), remove: vi.fn() }),
    createSeriesMarkers: vi.fn(),
  }
})

const none = { ema_9_21: null, ema_21_50: null, ema_stack: null, hma_up: null, alma_cross: null, aroon_cross: null, aroon_strong: null }
const values = { ema9: 1, ema21: 1, ema50: 1, hma: 1, alma: 1, aroon_up: 84, aroon_down: 20 }
const row = (symbol: string, signals: Partial<ScanRow["signals"]>, extra: Partial<ScanRow> = {}): ScanRow => ({
  symbol, name: symbol, sector: "Commercial Banks", close: 500, change_pct: 1.2, signals: { ...none, ...signals }, values, readiness: 70, in_buy_zone: false, guards: [], ...extra,
})

const stats = (avg: number) => ({ "5": { n: 100, avg_return_pct: avg, win_rate_pct: 40, avg_excess_pct: -0.5 }, "10": { n: 90, avg_return_pct: avg, win_rate_pct: 40, avg_excess_pct: -0.5 }, "20": { n: 80, avg_return_pct: avg, win_rate_pct: 30, avg_excess_pct: -1 } })
const chartFor = (symbol: string) => ({
  symbol, name: `${symbol} Ltd`, sector: "Commercial Banks", params: { ema: [9, 21, 50], hma: 21, alma: { length: 9, offset: 0.85, sigma: 6 }, aroon: 25 }, strong_aroon: 70,
  candles: [{ traded_on: "2026-11-04", open: 1, high: 2, low: 1, close: 2, volume: 10 }, { traded_on: "2026-11-05", open: 2, high: 3, low: 2, close: 3, volume: 10 }],
  lines: { ema9: [1, 2], ema21: [1, 2], ema50: [null, 1], hma: [1, 2], alma: [1, 2], aroon_up: [80, 84], aroon_down: [20, 16] },
  episodes: { ema_9_21: [{ start_on: "2026-11-04", start_price: 2, end_on: null, end_price: null, sessions: 1, change_pct: 50, open: true }], ema_21_50: [], ema_stack: [], hma_up: [], alma_cross: [], aroon_cross: [], aroon_strong: [] },
  signals: none,
})

const scan: CrossoverScan = {
  as_of: "2026-11-05",
  params: { ema: [9, 21, 50], hma: 21, alma: { length: 9, offset: 0.85, sigma: 6 }, aroon: 25 },
  strong_aroon: 70,
  rows: [
    row("FRESH", { ema_9_21: 1, ema_stack: 40 }, { in_buy_zone: true, readiness: 82 }),
    row("OLD", { ema_9_21: 12, ema_stack: 9 }),
    row("THIN", { ema_9_21: 0 }, { guards: ["thin_volume"] }),
  ],
  backtest: {
    period: { from: "2025-09-28", to: "2026-11-05" }, horizons: [5, 10, 20],
    signals: { all: stats(0.1), ema_9_21: stats(-2.8), ema_21_50: stats(-2), ema_stack: stats(-2.5), hma_up: stats(-1.3), alma_cross: stats(-0.8), aroon_cross: stats(-2.7), aroon_strong: stats(-2.6) },
  },
}

describe("ScannerPage", () => {
  beforeEach(() => {
    mockGet.mockReset().mockImplementation((path: string) => Promise.resolve({ data: path === "/scans/crossovers" ? scan : chartFor(path.split("/").pop() as string) }))
  })

  it("lists stocks whose 9/21 cross began in the last 3 sessions, hiding thin stocks", async () => {
    renderWithClient(<ScannerPage />)

    expect(await screen.findByRole("row", { name: "FRESH scan row" })).toHaveTextContent("9/21 1d")
    expect(screen.queryByRole("row", { name: "OLD scan row" })).not.toBeInTheDocument()
    expect(screen.queryByRole("row", { name: "THIN scan row" })).not.toBeInTheDocument()
    expect(screen.getByText("1 of 3 stocks")).toBeInTheDocument()
    expect(within(screen.getByRole("row", { name: "FRESH scan row" })).getByText("Entry zone")).toBeInTheDocument()
  })

  it("treats the EMA stack as a state, widens the window, and shows thin stocks on request", async () => {
    renderWithClient(<ScannerPage />)
    await screen.findByRole("row", { name: "FRESH scan row" })

    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 crossed above 21" })) // untick
    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 > 21 > 50" }))
    expect(screen.getByRole("row", { name: "OLD scan row" })).toBeInTheDocument() // stack began 9 sessions ago, still holds
    expect(screen.getByRole("row", { name: "FRESH scan row" })).toBeInTheDocument()

    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 > 21 > 50" }))
    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 crossed above 21" }))
    await userEvent.selectOptions(screen.getByRole("combobox"), "10")
    await userEvent.click(screen.getByLabelText("Hide thinly traded stocks"))
    expect(screen.getByText("2 of 3 stocks")).toBeInTheDocument() // OLD (12 sessions) still out; THIN now in
  })

  it("summarises the ticked signals' track record and expands into the table", async () => {
    renderWithClient(<ScannerPage />)

    expect(await screen.findByLabelText("Track record summary")).toHaveTextContent("20 sessions after the ticked signal: 9/21 -2.80% vs +0.10% for the average stock-day.")
    await userEvent.click(screen.getByRole("button", { name: "Show track record" }))
    const table = screen.getByRole("table", { name: "Signal track record" })
    expect(within(table).getByText("All stock-days (baseline)")).toBeInTheDocument()
    expect(within(table).getByText("-2.80% ▼")).toBeInTheDocument()
    await userEvent.click(screen.getByRole("tab", { name: "5 sessions" }))
    expect(within(table).getAllByText("-0.50%").length).toBeGreaterThan(0)
  })

  it("sorts by a column header", async () => {
    renderWithClient(<ScannerPage />)
    await screen.findByRole("row", { name: "FRESH scan row" })
    await userEvent.click(screen.getByLabelText("Hide thinly traded stocks"))
    await userEvent.selectOptions(screen.getByRole("combobox"), "10")

    await userEvent.click(screen.getByRole("button", { name: "Symbol" }))
    const order = () => screen.getAllByRole("row").map((r) => r.getAttribute("aria-label")).filter(Boolean)
    expect(order()).toEqual(["FRESH scan row", "THIN scan row"])
    await userEvent.click(screen.getByRole("button", { name: "Symbol" }))
    expect(order()).toEqual(["THIN scan row", "FRESH scan row"])
  })

  it("opens a stock's chart with its signal history, and steps through the results", async () => {
    renderWithClient(<ScannerPage />)
    await userEvent.click(await screen.findByLabelText("Hide thinly traded stocks"))
    await userEvent.click(await screen.findByRole("button", { name: "Chart FRESH" }))

    const panel = await screen.findByRole("dialog", { name: "FRESH chart" })
    expect(within(panel).getByText("1 of 2")).toBeInTheDocument()
    expect(await within(panel).findByTestId("indicator-chart")).toBeInTheDocument()
    expect(within(panel).getByLabelText("Signal history")).toHaveTextContent("9/212026-11-04 at 2.00still on1+50.00% so far")

    await userEvent.click(within(panel).getByRole("button", { name: "Next stock" }))
    expect(await screen.findByRole("dialog", { name: "THIN chart" })).toBeInTheDocument()
    await userEvent.click(screen.getByRole("button", { name: "Close chart" }))
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument()
  })
})
