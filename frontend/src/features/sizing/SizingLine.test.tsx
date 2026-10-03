import { render, screen } from "@testing-library/react"
import { MemoryRouter } from "react-router-dom"

import { SizingLine } from "./SizingLine"
import type { WatchlistSizing } from "./types"

const renderLine = (sizing: WatchlistSizing | null) => render(<MemoryRouter><SizingLine sizing={sizing} /></MemoryRouter>)

describe("SizingLine", () => {
  it("shows the shares, cost, loss at stop, break-even and target outcome", () => {
    renderLine({
      risk_budget: 5000, lot_size: 10, limited_by: "risk", entry: 500, stop: 470, quantity: 140, amount: 70_000,
      buy_costs: { amount: 70_000, commission: 231, sebon: 10.5, dp: 0, total: 241.5 }, total_cost: 70_241.5,
      loss_at_stop: 4_798.2, loss_pct_of_capital: 0.96, break_even: 503.64, gain_at_target: 8_051.33, reward_risk: 1.68,
    })

    expect(screen.getByLabelText("Position size")).toHaveTextContent(
      "Size: 140 shares at 500.00 = Rs 70,000.00 + Rs 241.50 fees · loss at stop 470.00: Rs 4,798.20 (0.96% of capital) · break-even 503.64 · at target +Rs 8,051.33 (1.68R)",
    )
  })

  it("asks for capital first, and explains when one lot is too much", () => {
    const { unmount } = renderLine(null)
    expect(screen.getByRole("link", { name: "Set your trading capital" })).toHaveAttribute("href", "/settings")
    unmount()

    renderLine({ risk_budget: 200, lot_size: 10, limited_by: "risk", quantity: 0, note: "Your risk budget is smaller than the loss on one 10-share lot at this stop" })
    expect(screen.getByLabelText("Position size")).toHaveTextContent("smaller than the loss on one 10-share lot")
  })
})
