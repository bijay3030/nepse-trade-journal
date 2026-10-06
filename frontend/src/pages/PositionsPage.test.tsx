import { fireEvent, screen, waitFor, within } from "@testing-library/react"
import { vi } from "vitest"

import type { Position } from "../features/positions/types"
import { renderWithClient } from "../test/renderWithClient"
import { PositionsPage } from "./PositionsPage"

const { mockGet, mockPatch, mockDelete } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPatch: vi.fn(), mockDelete: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet, post: vi.fn(), patch: mockPatch, delete: mockDelete } }))

const position: Position = {
  id: 3, symbol: "NABIL", name: "Nabil Bank", sector: "Commercial Banks", status: "open", setup_type: "vcp", watchlist_item_id: 7,
  quantity: 150, average_price: 510, last_price: 530, change_percent: 1.2, price_updated_at: null,
  stop_price: 470, initial_stop_price: 470, target_price: 560, unrealized_pnl: 3000, unrealized_pct: 3.92, r_multiple: 0.5,
  open_risk: 6000, cost_basis: 76_780.5, net_pnl_if_sold: 2_430.25, break_even_price: 513.84, opened_on: "2026-09-28", sellable_on: "2099-01-01", days_held: 5, closed_on: null, notes: "Breakout on volume",
  fills: [
    { id: 1, side: "buy", price: 500, quantity: 100, traded_on: "2026-09-28" },
    { id: 2, side: "buy", price: 530, quantity: 50, traded_on: "2026-10-01" },
  ],
}

const portfolio = {
  capital: 1_000_000, open_risk: 6000, market_value: 79_500, invested: 76_500, cash: 923_500,
  heat: { pct: 0.6, limit_pct: 6, state: "ok", room: 54_000 },
  positions: [{ position_id: 1, symbol: "NABIL", open_risk: 6000, heat_pct: 0.6, share_of_risk_pct: 100 }],
  sectors: [{ sector: "Commercial Banks", value: 79_500, pct: 7.95, symbols: ["NABIL"], over: false }],
}

describe("PositionsPage", () => {
  beforeEach(() => {
    mockGet.mockReset().mockImplementation((path: string) => {
      if (path === "/positions/portfolio") return Promise.resolve({ data: portfolio })
      if (path === "/position_alerts") return Promise.resolve({ data: { unread_count: 0, alerts: [] } })
      if (path === "/trading_settings") return Promise.resolve({ data: { trading_capital: 1_000_000, risk_per_trade_pct: 1, max_open_risk_pct: 6, max_sector_pct: 30 } })
      return Promise.resolve({ data: [position] })
    })
    mockPatch.mockReset()
    mockDelete.mockReset()
  })

  it("summarises open positions and shows each against its plan", async () => {
    renderWithClient(<PositionsPage />)

    const card = await screen.findByRole("article", { name: "NABIL position" })
    expect(mockGet).toHaveBeenCalledWith("/positions", { params: { status: "open" } })
    expect(screen.getAllByText("Rs +2,430.25")).toHaveLength(2) // summary (net if all sold) and the card
    expect(screen.getAllByText("Rs 6,000.00")).toHaveLength(2) // summary and the card
    expect(card).toHaveTextContent("150 shares at 510.00 · held 5 days")
    expect(card).toHaveTextContent("+3,000.00 (+3.92%)")
    expect(card).toHaveTextContent("+0.5R")
    expect(card).toHaveTextContent("470.00 (-11.32%)")
    expect(card).toHaveTextContent("560.00 (+5.66%)")
    expect(card).toHaveTextContent("Sellable from 2099-01-01")
    expect(card).toHaveTextContent("Breakout on volume")
    expect(card).toHaveTextContent("Cost incl. feesRs 76,780.50")
    expect(card).toHaveTextContent("Break-even513.84")
  })

  it("edits the stop and target", async () => {
    mockPatch.mockResolvedValue({ data: { ...position, stop_price: 510 } })
    renderWithClient(<PositionsPage />)

    fireEvent.click(await screen.findByRole("button", { name: /Edit stop \/ target/ }))
    fireEvent.change(screen.getByLabelText("Stop (Rs)"), { target: { value: "510" } })
    fireEvent.click(screen.getByRole("button", { name: "Save plan" }))

    await waitFor(() => expect(mockPatch).toHaveBeenCalledWith("/positions/3", { stop_price: 510, target_price: 560, notes: "Breakout on volume" }))
  })

  it("lists fills and removes one after confirming", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true)
    mockDelete.mockResolvedValue({ data: {} })
    renderWithClient(<PositionsPage />)

    fireEvent.click(await screen.findByRole("button", { name: "Fills (2)" }))
    const fills = screen.getByRole("list", { name: "NABIL fills" })
    expect(within(fills).getByText("2026-10-01 · Bought 50 at 530.00")).toBeInTheDocument()
    fireEvent.click(within(fills).getByRole("button", { name: "Remove fill from 2026-10-01" }))

    await waitFor(() => expect(mockDelete).toHaveBeenCalledWith("/positions/3/fills/2"))
  })

  it("explains how to add a position when there are none", async () => {
    mockGet.mockResolvedValue({ data: [] })
    renderWithClient(<PositionsPage />)

    expect(await screen.findByText("No open positions.")).toBeInTheDocument()
  })
})
