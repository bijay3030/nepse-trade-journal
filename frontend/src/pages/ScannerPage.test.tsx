import { screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import type { CrossoverScan, ScanRow } from "../features/scanner/types"
import { renderWithClient } from "../test/renderWithClient"
import { ScannerPage } from "./ScannerPage"

const { mockGet, mockPut } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPut: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet, put: mockPut } }))
vi.mock("lightweight-charts", () => {
  const series = { setData: vi.fn(), createPriceLine: vi.fn() }
  return {
    CandlestickSeries: "Candlestick", HistogramSeries: "Histogram", LineSeries: "Line", LineStyle: { Dashed: 2 },
    createChart: () => ({ addSeries: () => series, panes: () => [{ setHeight: vi.fn() }, { setHeight: vi.fn() }], priceScale: () => ({ applyOptions: vi.fn() }), timeScale: () => ({ fitContent: vi.fn() }), remove: vi.fn() }),
    createSeriesMarkers: vi.fn(),
  }
})

const none = { ema_9_21: null, ema_stack: null, hma_up: null, alma_cross: null, aroon_cross: null, aroon_strong: null }
const values = { ema9: 1, ema21: 1, ema50: 1, hma: 1, alma: 1, aroon_up: 84, aroon_down: 20 }
const row = (symbol: string, signals: Partial<ScanRow["signals"]>, extra: Partial<ScanRow> = {}): ScanRow => ({
  symbol, name: symbol, sector: "Commercial Banks", close: 500, change_pct: 1.2, signals: { ...none, ...signals }, values, readiness: 70, in_buy_zone: false, guards: [], ...extra,
})

const stats = (avg: number) => ({ "5": { n: 100, avg_return_pct: avg / 2, win_rate_pct: 40 }, "10": { n: 90, avg_return_pct: avg, win_rate_pct: 40 }, "20": { n: 80, avg_return_pct: avg, win_rate_pct: 30 } })
const years = (avg: number) => ({ "2022": { n: 40, avg_return_pct: avg, win_rate_pct: 35 }, "2023": { n: 40, avg_return_pct: avg + 1, win_rate_pct: 45 } })
const chartFor = (symbol: string) => ({
  symbol, name: `${symbol} Ltd`, sector: "Commercial Banks", params: { ema: [9, 21, 50], hma: 55, alma: { length: 21, offset: 0.85, sigma: 6 }, aroon: 25 }, strong_aroon: 70,
  candles: [{ traded_on: "2026-11-04", open: 1, high: 2, low: 1, close: 2, volume: 10 }, { traded_on: "2026-11-05", open: 2, high: 3, low: 2, close: 3, volume: 10 }],
  lines: { ema9: [1, 2], ema21: [1, 2], ema50: [null, 1], hma: [1, 2], alma: [1, 2], aroon_up: [80, 84], aroon_down: [20, 16] },
  episodes: { ema_9_21: [{ start_on: "2026-11-04", start_price: 2, end_on: null, end_price: null, sessions: 1, change_pct: 50, open: true }], ema_stack: [], hma_up: [], alma_cross: [], aroon_cross: [], aroon_strong: [] },
  signals: none,
})

const scan: CrossoverScan = {
  as_of: "2026-11-05",
  params: { ema: [9, 21, 50], hma: 55, alma: { length: 21, offset: 0.85, sigma: 6 }, aroon: 25 },
  strong_aroon: 70,
  rows: [
    row("FRESH", { ema_9_21: 1, ema_stack: 40 }, { in_buy_zone: true, readiness: 82, signal_volume: { ema_9_21: 2.1, ema_stack: 0.8 } }),
    row("OLD", { ema_9_21: 12, ema_stack: 9 }, { signal_volume: { ema_9_21: 1.6, ema_stack: 1.7 } }),
    row("THIN", { ema_9_21: 0 }, { guards: ["thin_volume"], signal_volume: { ema_9_21: 3 } }),
    row("QUIET", { ema_9_21: 2 }, { signal_volume: { ema_9_21: 0.9 } }),
  ],
  backtest: {
    period: { from: "2020-01-01", to: "2026-11-05" }, horizons: [5, 10, 20], year_horizon: 20, strong_volume: 1.5,
    signals_with_volume: { ema_9_21: stats(1.4), ema_stack: stats(0.3), hma_up: stats(2.2), alma_cross: stats(0.4), aroon_cross: stats(0.6), aroon_strong: stats(0.9) },
    by_year: { all: years(0.5), ema_9_21: years(1), ema_stack: years(0), hma_up: years(2), alma_cross: years(0.5), aroon_cross: years(0.2), aroon_strong: years(1.2) },
    signals: { all: stats(0.1), ema_9_21: stats(-2.8), ema_stack: stats(-2.5), hma_up: stats(-1.3), alma_cross: stats(-0.8), aroon_cross: stats(-2.7), aroon_strong: stats(-2.6) },
  },
}

let alert: { signals: string[]; volume: boolean; telegram_linked: boolean } = { signals: [], volume: true, telegram_linked: true }

describe("ScannerPage", () => {
  beforeEach(() => {
    mockGet.mockReset().mockImplementation((path: string) => {
      if (path === "/scans/alert") return Promise.resolve({ data: alert })
      return Promise.resolve({ data: path === "/scans/crossovers" ? scan : chartFor(path.split("/").pop() as string) })
    })
    mockPut.mockReset().mockImplementation((_path: string, body: { signals: string[]; volume: boolean }) => Promise.resolve({ data: { ...body, telegram_linked: true } }))
    alert = { signals: [], volume: true, telegram_linked: true }
  })

  it("lists stocks whose 9/21 cross began in the last 3 sessions on strong volume, hiding thin stocks", async () => {
    renderWithClient(<ScannerPage />)

    expect(await screen.findByRole("row", { name: "FRESH scan row" })).toHaveTextContent("9/21 1d· 2.1× vol")
    expect(screen.queryByRole("row", { name: "OLD scan row" })).not.toBeInTheDocument()
    expect(screen.queryByRole("row", { name: "THIN scan row" })).not.toBeInTheDocument()
    expect(screen.queryByRole("row", { name: "QUIET scan row" })).not.toBeInTheDocument() // 0.9x volume
    expect(screen.getByText("1 of 4 stocks")).toBeInTheDocument()
    expect(within(screen.getByRole("row", { name: "FRESH scan row" })).getByText("Entry zone")).toBeInTheDocument()

    await userEvent.click(screen.getByLabelText("Volume ≥ 1.5× on the signal day"))
    expect(screen.getByRole("row", { name: "QUIET scan row" })).toBeInTheDocument()
    expect(screen.getByText("2 of 4 stocks")).toBeInTheDocument()
  })

  it("treats the EMA stack as a state, widens the window, and shows thin stocks on request", async () => {
    renderWithClient(<ScannerPage />)
    await screen.findByRole("row", { name: "FRESH scan row" })

    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 crossed above 21" })) // untick
    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 > 21 > 50" }))
    expect(screen.getByRole("row", { name: "OLD scan row" })).toBeInTheDocument() // stack began 9 sessions ago, still holds
    expect(screen.queryByRole("row", { name: "FRESH scan row" })).not.toBeInTheDocument() // its stack began on 0.8x volume
    await userEvent.click(screen.getByLabelText("Volume ≥ 1.5× on the signal day"))
    expect(screen.getByRole("row", { name: "FRESH scan row" })).toBeInTheDocument()
    await userEvent.click(screen.getByLabelText("Volume ≥ 1.5× on the signal day"))

    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 > 21 > 50" }))
    await userEvent.click(screen.getByRole("checkbox", { name: "EMA 9 crossed above 21" }))
    await userEvent.selectOptions(screen.getByRole("combobox"), "10")
    await userEvent.click(screen.getByLabelText("Hide thinly traded stocks"))
    expect(screen.getByText("2 of 4 stocks")).toBeInTheDocument() // OLD (12 sessions) still out; THIN now in; QUIET out on volume
  })

  it("summarises the ticked signals' track record and expands into the table", async () => {
    renderWithClient(<ScannerPage />)

    expect(await screen.findByLabelText("Track record summary")).toHaveTextContent(
      "Track record on NEPSE since 2020: 20 sessions after the ticked signal began: 9/21 -2.80% (+1.40% on 1.5× volume) vs +0.10% for the average stock-day.",
    )
    await userEvent.click(screen.getByRole("button", { name: "Show track record" }))
    const table = screen.getByRole("table", { name: "Signal track record" })
    const nineTwentyOne = within(table).getByText("EMA 9 crossed above 21").closest("tr") as HTMLElement
    expect(nineTwentyOne).toHaveTextContent("80-2.80%30%-2.90%+1.40%30%") // vs baseline -2.90; on volume +1.40
    await userEvent.click(screen.getByRole("tab", { name: "5 sessions" }))
    expect(nineTwentyOne).toHaveTextContent("-1.40%")

    const byYear = screen.getByRole("table", { name: "Track record by year" })
    expect(within(byYear).getByText("EMA 9 > 21 > 50").closest("tr")).toHaveTextContent("0.00% ▼+1.00% ▼") // below the baseline both years
    expect(within(byYear).getByText("HMA 55 turned up").closest("tr")).toHaveTextContent("+2.00%+3.00%")
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

  it("saves the ticked signals as the Telegram alert filter, and stops it", async () => {
    renderWithClient(<ScannerPage />)

    await userEvent.click(await screen.findByRole("button", { name: "Alert me on Telegram" }))
    expect(mockPut).toHaveBeenCalledWith("/scans/alert", { signals: ["ema_9_21"], volume: true })
    expect(await screen.findByText("Telegram alerts on for this filter")).toBeInTheDocument()

    await userEvent.click(screen.getByRole("checkbox", { name: "Aroon Up ≥ 70" }))
    expect(screen.getByLabelText("Telegram alerts")).toHaveTextContent("Telegram alerts on for: 9/21")
    expect(screen.getByRole("button", { name: "Alert me for this filter instead" })).toBeInTheDocument()

    await userEvent.click(screen.getByRole("button", { name: "Stop alerts" }))
    expect(mockPut).toHaveBeenLastCalledWith("/scans/alert", { signals: [], volume: true })
  })

  it("saves the volume filter with the alert", async () => {
    alert = { signals: ["ema_9_21"], volume: true, telegram_linked: true }
    renderWithClient(<ScannerPage />)

    expect(await screen.findByText("Telegram alerts on for this filter")).toBeInTheDocument()
    await userEvent.click(screen.getByLabelText("Volume ≥ 1.5× on the signal day"))
    expect(screen.getByLabelText("Telegram alerts")).toHaveTextContent("Telegram alerts on for: 9/21 on 1.5× volume")
    await userEvent.click(screen.getByRole("button", { name: "Alert me for this filter instead" }))
    expect(mockPut).toHaveBeenLastCalledWith("/scans/alert", { signals: ["ema_9_21"], volume: false })
  })

  it("asks to connect Telegram first", async () => {
    alert = { signals: [], volume: true, telegram_linked: false }
    renderWithClient(<ScannerPage />)

    expect(await screen.findByRole("link", { name: "Connect Telegram" })).toHaveAttribute("href", "/settings")
  })
})
