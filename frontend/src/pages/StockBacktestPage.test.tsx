import { screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { Route, Routes } from "react-router-dom"
import { vi } from "vitest"

import type { StockBacktest } from "../features/lab/types"
import { renderWithClient } from "../test/renderWithClient"
import { StockBacktestPage } from "./StockBacktestPage"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet } }))
vi.mock("../features/lab/TradesChart", () => ({ TradesChart: ({ trades }: { trades: unknown[] }) => <div data-testid="trades-chart">{trades.length} trades charted</div> }))

const strategy = (key: string, label: string, pf: number, trades: number) => ({
  key, label, family: "Indicator Scanner" as const, signals: trades + 2, latest_signal: "2026-11-20", sessions_since_signal: 0, forward20: null,
  stats: { trades, open: 0, win_rate_pct: 51.3, profit_factor: pf, avg_return_pct: 1.63, total_return_pct: 57, max_drawdown_pct: -28.9, best_pct: 15.4, worst_pct: -8.8, avg_hold: 8.9, by_year: { "2024": { trades: 12, total_return_pct: 48.5 } } },
})
const report: StockBacktest = {
  symbol: "BEDC", name: "Bhugol Energy Development Company Limited", sector: "Hydropower", sessions: 785, from: "2023-06-08", to: "2026-11-20", close: 306,
  rules: { hold: 20, max_stop_pct: 8, reward_multiple: 2, cost_pct: 0.8, max_gap_pct: 3 },
  buy_hold: { return_pct: 37.2, max_drawdown_pct: -73, by_year: { "2024": 138.6, "2025": -24.4 } },
  baseline: { "20": { count: 765, avg_pct: 1.31, up_pct: 47 } },
  strategies: [strategy("scan_alma_cross", "Close above ALMA 21", 1.45, 39), strategy("macd_cross", "MACD crosses its signal", 1.43, 22)],
  trades: [
    { key: "scan_alma_cross", signal_on: "2023-09-04", entry_on: "2023-09-05", exit_on: "2023-09-11", entry: 178.4, exit: 198.6, return_pct: 10.52, reason: "target", open: false, held_sessions: 4, held_days: 6 },
    { key: "macd_cross", signal_on: "2024-02-07", entry_on: "2024-02-08", exit_on: "2024-02-09", entry: 350, exit: 330, return_pct: -6.5, reason: "stop", open: false, held_sessions: 1, held_days: 1 },
  ],
  prices: [{ date: "2023-06-08", close: 223 }, { date: "2026-11-20", close: 306 }],
  now: { rsi: 58.5, sma50: 296.57, sma200: 387.7, macd: -0.15, macd_signal: -0.85, bb_lower: 287.15, high_52w: 716, low_52w: 278,
    levels: { entry_low: 311.6, entry_high: 320.95, stop: 292, target: 348.6, source: "board_setup", setup_type: "vcp" }, readiness: 37, trend_rules_passed: 1, rs_rating: 15, in_buy_zone: false },
}

function renderAt(path: string) {
  return renderWithClient(<Routes><Route path="/stock-backtest/:symbol?" element={<StockBacktestPage />} /></Routes>, { route: path })
}

describe("StockBacktestPage", () => {
  beforeEach(() => {
    mockGet.mockReset().mockImplementation((path: string) => Promise.resolve({ data: path === "/stocks" ? [{ symbol: "BEDC", name: "Bhugol" }] : report }))
  })

  it("summarises the best strategy and logs each trade's signal, buy, sell, holding time and result", async () => {
    renderAt("/stock-backtest/BEDC")

    expect(await screen.findByLabelText("Summary")).toHaveTextContent("Close above ALMA 21 has the best record on BEDC: profit factor 1.45 over 39 trades (51.3% won, +57.0% compounded), holding about 8.9 sessions a trade.")
    expect(mockGet).toHaveBeenCalledWith("/lab/stocks/BEDC")
    expect(screen.getByRole("heading", { name: "Trade log: Close above ALMA 21" })).toBeInTheDocument()
    expect(screen.getByText(/on the session when the close moves above the 21-day ALMA, it buys at the next session's open/)).toBeInTheDocument()
    const log = screen.getByRole("table", { name: "Trade log" })
    expect(within(log).getAllByRole("row")[1]).toHaveTextContent("1Mon 4 Sep 2023Tue 5 Sep 2023178.40Mon 11 Sep 2023198.604 sessions6 daysTarget hit+10.52%")
  })

  it("switches the trade log to the strategy clicked in the ranking", async () => {
    renderAt("/stock-backtest/BEDC")
    await screen.findByLabelText("Summary")

    await userEvent.click(screen.getByRole("button", { name: "MACD crosses its signal" }))
    const log = screen.getByRole("table", { name: "Trade log" })
    expect(within(log).getAllByRole("row")[1]).toHaveTextContent("1 session1 dayStop hit-6.50%")
    expect(screen.getByTestId("trades-chart")).toHaveTextContent("1 trades charted")
  })

  it("asks for a symbol when none is given", async () => {
    renderAt("/stock-backtest")
    expect(await screen.findByText("Enter a stock symbol to backtest every strategy on it.")).toBeInTheDocument()
  })
})
