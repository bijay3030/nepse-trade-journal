import { screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import type { LabReport } from "../features/lab/types"
import { renderWithClient } from "../test/renderWithClient"
import { LabPage } from "./LabPage"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet } }))

const stats = (pf: number, trades = 100) => ({ trades, win_rate_pct: 40, avg_return_pct: -0.5, avg_r: 0.1, profit_factor: pf })
const report = (overrides: Partial<LabReport> = {}): LabReport => ({
  as_of: "2026-11-20", period: { from: "2020-01-01", to: "2026-11-20" }, oos_from: "2025-01-01",
  rules: { min_trades: 10, min_profit_factor: 1.3, min_oos_trades: 3, cost_pct: 0.8 },
  strategies: [{ key: "rsi_reversion", label: "RSI mean reversion", hold: 20 }, { key: "range_grid", label: "Range (grid) bounce", hold: 30 }],
  leaderboard: {
    rsi_reversion: { ...stats(0.76, 484), oos: stats(0.65), by_year: { "2024": stats(1.12) }, by_phase: { uptrend: stats(0.36, 147), sideways: stats(1.73), downtrend: stats(0.84) } },
    range_grid: { ...stats(0.86, 1551), oos: stats(0.91), by_year: { "2024": stats(1.42) }, by_phase: { uptrend: stats(0.69, 422), sideways: stats(1.09), downtrend: stats(0.84) } },
  },
  candidates: [],
  qualifying: { rsi_reversion: [], range_grid: [{ symbol: "GBBL", trades: 11, profit_factor: 3.78 }] },
  market_phase: { phase: "uptrend", sessions: 3 },
  paper_trades: { summary: { total: 0, open: 0, pending: 0, skipped: 0, closed: 0, win_rate_pct: null, avg_return_pct: null, profit_factor: null }, trades: [] },
  ...overrides,
})

describe("LabPage", () => {
  beforeEach(() => mockGet.mockReset())

  it("says plainly how the strategies did, and which stocks it's watching when none qualifies", async () => {
    mockGet.mockResolvedValue({ data: report() })
    renderWithClient(<LabPage />)

    expect(await screen.findByText(/Across all stocks since 2020/)).toBeInTheDocument()
    expect(screen.getByText(/Across all stocks since 2020/).closest("div")).toHaveTextContent("484 trades, profit factor 0.76 (lost money overall) · when NEPSE was uptrend, as now: 0.36 (147 trades)")
    expect(screen.getByLabelText("Qualifying stocks")).toHaveTextContent("Range (grid) bounce: watching 1 stock with a good record: GBBL (PF 3.78)")
    expect(within(screen.getByRole("table", { name: "Strategy leaderboard" })).getAllByRole("row")).toHaveLength(3)
    expect(screen.getByText(/No paper trades yet/)).toBeInTheDocument()
  })

  it("shows a candidate's levels and record, and the paper trades", async () => {
    mockGet.mockResolvedValue({ data: report({
      candidates: [{
        stock_id: 1, symbol: "GBBL", name: "Garima Bikas Bank", sector: "Development Banks", strategy: "range_grid", signal_on: "2026-11-20", close: 400, change_pct: 1.2, rsi: 38,
        levels: { entry_low: 400, entry_high: 408, stop: 380, target: 450, reward_risk: 2.5, range_low: 392, range_high: 470 },
        record: { trades: 11, win_rate_pct: 64, avg_return_pct: 3.1, profit_factor: 3.78, max_drawdown_pct: -9.5, oos: { trades: 4, avg_return_pct: 2.2 } },
        readiness: 55, guards: [],
      }],
      paper_trades: {
        summary: { total: 2, open: 1, pending: 0, skipped: 0, closed: 1, win_rate_pct: 100, avg_return_pct: 6.2, profit_factor: null },
        trades: [
          { id: 2, symbol: "GBBL", strategy: "range_grid", signal_on: "2026-11-20", levels: { entry_low: 400, entry_high: 408, stop: 380, target: 450, reward_risk: 2.5 }, status: "open",
            entry_on: "2026-11-23", entry_price: 402, exit_on: null, exit_price: 410, exit_reason: null, return_pct: 1.99, r_multiple: 0.4 },
          { id: 1, symbol: "HBL", strategy: "range_grid", signal_on: "2026-10-01", levels: { entry_low: 200, entry_high: 204, stop: 190, target: 225, reward_risk: 2.5 }, status: "closed",
            entry_on: "2026-10-02", entry_price: 201, exit_on: "2026-10-20", exit_price: 225, exit_reason: "target", return_pct: 6.2, r_multiple: 2.1 },
        ],
      },
    }) })
    renderWithClient(<LabPage />)

    const card = await screen.findByRole("article", { name: "GBBL candidate" })
    expect(card).toHaveTextContent("Entry range400.00–408.00")
    expect(card).toHaveTextContent("Stop380.00")
    expect(card).toHaveTextContent("Target450.00+12.5%")
    expect(within(card).getByLabelText("Record on this stock")).toHaveTextContent("On GBBL since 2020: 11 trades, 64% won, profit factor 3.78")

    const table = screen.getByRole("table", { name: "Paper trades" })
    expect(within(table).getAllByRole("row")).toHaveLength(3)
    await userEvent.click(screen.getByRole("tab", { name: "closed" }))
    expect(within(screen.getByRole("table", { name: "Paper trades" })).getAllByRole("row")).toHaveLength(2)
    expect(screen.getByRole("table", { name: "Paper trades" })).toHaveTextContent("HBLRange (grid) bounce2026-10-01closed201.00190.00 / 225.00225.00 · target+6.20%")
  })
})
