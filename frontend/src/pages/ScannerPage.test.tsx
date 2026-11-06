import { screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import type { CrossoverScan, ScanRow } from "../features/scanner/types"
import { renderWithClient } from "../test/renderWithClient"
import { ScannerPage } from "./ScannerPage"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet } }))

const none = { ema_9_21: null, ema_21_50: null, ema_stack: null, hma_up: null, alma_cross: null, aroon_cross: null, aroon_strong: null }
const values = { ema9: 1, ema21: 1, ema50: 1, hma: 1, alma: 1, aroon_up: 84, aroon_down: 20 }
const row = (symbol: string, signals: Partial<ScanRow["signals"]>, extra: Partial<ScanRow> = {}): ScanRow => ({
  symbol, name: symbol, sector: "Commercial Banks", close: 500, change_pct: 1.2, signals: { ...none, ...signals }, values, readiness: 70, in_buy_zone: false, guards: [], ...extra,
})

const stats = (avg: number) => ({ "5": { n: 100, avg_return_pct: avg, win_rate_pct: 40, avg_excess_pct: -0.5 }, "10": { n: 90, avg_return_pct: avg, win_rate_pct: 40, avg_excess_pct: -0.5 }, "20": { n: 80, avg_return_pct: avg, win_rate_pct: 30, avg_excess_pct: -1 } })
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
  beforeEach(() => mockGet.mockReset().mockResolvedValue({ data: scan }))

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

  it("shows each signal's track record and marks those worse than the baseline", async () => {
    renderWithClient(<ScannerPage />)

    const table = await screen.findByRole("table", { name: "Signal track record" })
    expect(within(table).getByText("All stock-days (baseline)")).toBeInTheDocument()
    expect(within(table).getByText("-2.80% ▼")).toBeInTheDocument()
    await userEvent.click(screen.getByRole("tab", { name: "5 sessions" }))
    expect(within(table).getAllByText("-0.50%").length).toBeGreaterThan(0)
  })
})
