import { screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import type { PaperAccount, PaperTradeRow } from "../features/paper/types"
import { renderWithClient } from "../test/renderWithClient"
import { PaperTradingPage } from "./PaperTradingPage"

const { mockGet, mockPatch } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPatch: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet, patch: mockPatch } }))

const trade = (o: Partial<PaperTradeRow>): PaperTradeRow => ({
  id: 1, symbol: "AHPC", name: "Arun Valley", status: "open", trigger: "watchlist_entered_zone", signal_on: "2026-11-23", quantity: 10,
  buy_reason: "Watchlist alert: AHPC entered its zone at 260.00.", entry_price: 261.3, entry_at: "2026-11-23T11:30:00+05:45", buy_costs: 9.8,
  stop_price: 251.81, target_price: 290, last_price: 270, sellable_on: "2026-11-25", unrealized_pnl: 72.5,
  exit_price: null, exit_at: null, exit_rule: null, sell_reason: null, sell_costs: null, cgt: null, net_pnl: null, return_pct: null, held_days: 0, ...o,
})
const account: PaperAccount = {
  enabled: true, quantity: 10, slippage_pct: 0.5,
  summary: { open: 1, pending: 1, closed: 1, invested: 2622.8, open_pnl: 72.5, realized_pnl: -142.3, win_rate_pct: 0, profit_factor: null },
  trades: [
    trade({}),
    trade({ id: 2, symbol: "EBL", status: "pending", trigger: "board_new", entry_price: null, entry_at: null, signal_on: "2026-11-20" }),
    trade({ id: 3, symbol: "NMB", status: "closed", entry_at: "2026-11-10T11:20:00+05:45", entry_price: 280, exit_at: "2026-11-14T13:00:00+05:45", exit_price: 266.5,
      exit_rule: "stop_hit", sell_reason: "NMB at 267.80, at or under the 268.00 stop.", net_pnl: -142.3, return_pct: -5.07, held_days: 4 }),
  ],
  log: [
    { id: 9, at: "2026-11-23T11:30:00+05:45", action: "buy", symbol: "AHPC", price: 261.3, reason: "Bought 10 at 261.30 (live 260.00 + 0.5% slippage).", trade_id: 1 },
    { id: 8, at: "2026-11-23T11:35:00+05:45", action: "skip", symbol: "AHPC", price: 262, reason: "AHPC signal skipped: already holding it.", trade_id: null },
  ],
}

describe("PaperTradingPage", () => {
  beforeEach(() => {
    mockGet.mockReset().mockResolvedValue({ data: account })
    mockPatch.mockReset().mockImplementation((_p: string, body: { enabled: boolean }) => Promise.resolve({ data: { ...account, enabled: body.enabled } }))
  })

  it("shows open and closed paper trades with why they were bought and sold, and the log", async () => {
    renderWithClient(<PaperTradingPage />)

    const open = await screen.findByRole("table", { name: "Open paper positions" })
    expect(within(open).getAllByRole("row")[1]).toHaveTextContent("AHPCWatchlist: entered zoneWatchlist alert: AHPC entered its zone at 260.00.")
    expect(within(open).getAllByRole("row")[1]).toHaveTextContent("261.30270.00+Rs 72.50251.81 / 290.00Wed 25 Nov")
    expect(screen.getByLabelText("Waiting to buy")).toHaveTextContent("EBL (New on Entry zone, Fri 20 Nov)")

    const closed = screen.getByRole("table", { name: "Closed paper trades" })
    expect(within(closed).getAllByRole("row")[1]).toHaveTextContent("4 daysStop hitNMB at 267.80, at or under the 268.00 stop.-Rs 142.30-5.07%")

    await userEvent.click(screen.getByRole("button", { name: "Skipped" }))
    expect(screen.getByLabelText("Paper trading log")).toHaveTextContent("AHPC signal skipped: already holding it.")
    expect(screen.getByLabelText("Paper trading log")).not.toHaveTextContent("Bought 10")
  })

  it("turns automated paper trading off", async () => {
    renderWithClient(<PaperTradingPage />)
    await userEvent.click(await screen.findByRole("checkbox"))
    await waitFor(() => expect(mockPatch).toHaveBeenCalledWith("/paper_trading", { enabled: false }))
  })
})
