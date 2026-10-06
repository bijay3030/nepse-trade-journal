import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"

import api from "../../lib/axios"
import { PositionAlertsPanel } from "./PositionAlertsPanel"
import type { PositionAlert } from "./types"

vi.mock("../../lib/axios", () => ({ default: { get: vi.fn(), post: vi.fn(), patch: vi.fn() } }))

const alert = (overrides: Partial<PositionAlert>): PositionAlert => ({
  id: 1, position_id: 7, symbol: "NABIL", kind: "one_r", message: "NABIL is up 1R at 108.50 (1.06R).", price: 108.5,
  read_at: null, created_at: new Date().toISOString(), position_open: true, stop_price: 92, break_even_price: 100.92, ...overrides,
})

function renderPanel(alerts: PositionAlert[]) {
  vi.mocked(api.get).mockResolvedValue({ data: { unread_count: alerts.filter((a) => !a.read_at).length, alerts } })
  vi.mocked(api.patch).mockResolvedValue({ data: {} })
  render(<QueryClientProvider client={new QueryClient()}><PositionAlertsPanel /></QueryClientProvider>)
}

describe("PositionAlertsPanel", () => {
  it("lists sell-rule alerts and moves the stop to break-even on request", async () => {
    renderPanel([alert({}), alert({ id: 2, kind: "stop_hit", message: "NABIL is at 91.50, at or below your 92.00 stop.", break_even_price: null })])

    expect(await screen.findByText("Up 1R")).toBeInTheDocument()
    expect(screen.getByText("Stop hit")).toBeInTheDocument()
    expect(screen.getByText("2 new")).toBeInTheDocument()

    await userEvent.click(screen.getByRole("button", { name: "Move stop to break-even (100.92)" }))
    expect(api.patch).toHaveBeenCalledWith("/positions/7", { stop_price: 100.92 })
  })

  it("hides the button once the stop is at break-even, and shows nothing without alerts", async () => {
    renderPanel([alert({ stop_price: 101 })])
    expect(await screen.findByText("Up 1R")).toBeInTheDocument()
    expect(screen.queryByRole("button", { name: /Move stop/ })).not.toBeInTheDocument()
  })
})
