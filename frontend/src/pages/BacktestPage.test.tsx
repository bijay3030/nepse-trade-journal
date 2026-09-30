import { render, screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import { vi } from "vitest"

import type { BacktestRun, GroupStats } from "../features/backtest/types"
import { BacktestPage } from "./BacktestPage"

const mockUseBacktest = vi.fn()
vi.mock("../features/backtest/api", () => ({ useBacktest: () => mockUseBacktest() }))

const stats = (avg: number, n = 120): GroupStats => ({
  "5": { n, avg_return_pct: avg / 2, median_return_pct: 0, win_rate_pct: 50, avg_excess_pct: 0.1 },
  "10": { n, avg_return_pct: avg, median_return_pct: 0, win_rate_pct: 55, avg_excess_pct: avg - 0.5 },
  "20": { n, avg_return_pct: avg * 2, median_return_pct: 0, win_rate_pct: 60, avg_excess_pct: 1 },
})

const run: BacktestRun = {
  id: 3,
  created_at: "2026-09-30T11:00:00Z",
  from_date: "2026-05-11",
  to_date: "2026-09-28",
  sessions: 100,
  parameters: { horizons: [5, 10, 20], max_hold: 20, round_trip_cost_pct: 0.8, readiness_bands: ["0-19", "20-39", "40-59", "60+"] },
  results: {
    period: { from: "2026-05-11", to: "2026-09-28", sessions: 100, snapshots: 27000, stocks: 275 },
    baseline: stats(0.3, 25000),
    groups: {
      readiness: { "0-19": stats(-1.2), "20-39": stats(0.1), "40-59": stats(0.9), "60+": stats(2.4, 12) },
      zone_state: { in_zone: stats(0.8), too_early: stats(0.2) },
      flow_state: { accumulation: stats(1.5), distribution: stats(-0.7), neutral: stats(0.2) },
      trend: { "5+ of 7 rules": stats(1.1), "under 5": stats(-0.1) },
      entry_zone: { "Entry zone now": stats(2.4, 12), "Everything else": stats(0.2) },
    },
    trades: {
      total: 9, closed: 8, open: 1, skipped: 2, min_risk_pct: 1, win_rate_pct: 50, avg_return_pct: 1.84, avg_r: 0.42, median_r: 0.26, avg_win_pct: 7.1, avg_loss_pct: -3.4,
      profit_factor: 2.09, avg_sessions_held: 9.5, exits: { target: 3, stop: 4, time: 1 },
      list: [
        { symbol: "KBL", signal_on: "2026-08-10", entry_on: "2026-08-11", entry: 221, stop: 207.1, target: 250, status: "closed", exit_on: "2026-08-25", exit: 250, exit_reason: "target", return_pct: 12.32, r_multiple: 2.09, sessions_held: 11 },
      ],
    },
  },
}

function renderPage() {
  return render(<MemoryRouter><BacktestPage /></MemoryRouter>)
}

describe("BacktestPage", () => {
  it("summarises the simulated trades and warns about a small sample", () => {
    mockUseBacktest.mockReturnValue({ data: run, isLoading: false, isError: false })
    renderPage()

    expect(screen.getByText(/from 2026-05-11 to 2026-09-28: 100 sessions, 275 stocks/)).toBeInTheDocument()
    expect(screen.getByText("Closed trades").nextSibling).toHaveTextContent("8")
    expect(screen.getByText("Profit factor").nextSibling).toHaveTextContent("2.09")
    expect(screen.getByText("Median R multiple").nextSibling).toHaveTextContent("0.26R")
    expect(screen.getByText("1 still open, 2 skipped")).toBeInTheDocument()
    expect(screen.getByText("Target reached: 3")).toBeInTheDocument()
    expect(screen.getByText(/Only 8 closed trades: too few to judge the rules/)).toBeInTheDocument()
    const row = screen.getByRole("link", { name: "KBL" }).closest("tr") as HTMLElement
    expect(within(row).getByText("12.32%")).toBeInTheDocument()
    expect(within(row).getByText("2.09R")).toBeInTheDocument()
  })

  it("switches the forward-return horizon and marks small groups", async () => {
    mockUseBacktest.mockReturnValue({ data: run, isLoading: false, isError: false })
    renderPage()

    expect(screen.getByText(/All snapshots: avg 0.3%, win rate 55%/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole("tab", { name: "20 sessions" }))
    expect(screen.getByText(/All snapshots: avg 0.6%, win rate 60%/)).toBeInTheDocument()
    expect(screen.getAllByText("small sample").length).toBeGreaterThan(0)
    expect(screen.getAllByText("Accumulation").length).toBeGreaterThan(0)
  })

  it("orders readiness bands low to high even when the stored keys are reordered", () => {
    const reordered = { "60+": stats(2.4, 12), "0-19": stats(-1.2), "20-39": stats(0.1), "40-59": stats(0.9) }
    mockUseBacktest.mockReturnValue({ data: { ...run, results: { ...run.results, groups: { ...run.results.groups, readiness: reordered } } }, isLoading: false, isError: false })
    renderPage()

    const table = screen.getAllByRole("table").find((candidate) => within(candidate).queryByText("40-59")) as HTMLElement
    const groups = within(table).getAllByRole("row").slice(1).map((row) => row.firstElementChild?.textContent?.replace("small sample", ""))
    expect(groups).toEqual(["0-19", "20-39", "40-59", "60+"])
  })

  it("explains how to create the first backtest", () => {
    mockUseBacktest.mockReturnValue({ data: undefined, isLoading: false, isError: true })
    renderPage()

    expect(screen.getByText("No backtest yet.")).toBeInTheDocument()
  })
})
