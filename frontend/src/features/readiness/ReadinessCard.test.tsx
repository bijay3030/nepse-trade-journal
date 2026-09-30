import { render, screen, within } from "@testing-library/react"

import { ReadinessCard } from "./ReadinessCard"
import { readinessSnapshot } from "./testData"

describe("ReadinessCard", () => {
  it("shows the score, zone, levels and each component", () => {
    render(<ReadinessCard snapshot={readinessSnapshot()} />)

    expect(screen.getByRole("img", { name: "Entry readiness 68 of 100" })).toBeInTheDocument()
    expect(screen.getByText("Meets entry-zone criteria")).toBeInTheDocument()
    expect(screen.getByText(/zone 221.00–227.63/)).toBeInTheDocument()
    expect(screen.getByText("31/35")).toBeInTheDocument()
    expect(screen.getByText("20/20")).toBeInTheDocument()
    expect(screen.getByText("Sector index +3.95 points vs NEPSE over 20 sessions.")).toBeInTheDocument()
    expect(within(screen.getByRole("list", { name: "Zone: In entry zone" })).getByText("In entry zone")).toHaveAttribute("aria-current", "step")
  })

  it("lists every trend-template rule with its result", () => {
    render(<ReadinessCard snapshot={readinessSnapshot()} />)

    expect(screen.getAllByLabelText("Met")).toHaveLength(2)
    expect(screen.getByLabelText("Not met")).toBeInTheDocument()
    expect(screen.getByText("209.10 -> 207.50")).toBeInTheDocument()
  })

  it("shows the distance for a stock below its zone and never uses advice words", () => {
    const { container } = render(<ReadinessCard snapshot={readinessSnapshot({ zone_state: "too_early", in_buy_zone: false, distance_to_zone_pct: 2.4 })} />)

    expect(screen.getByText(/2.40% below the zone/)).toBeInTheDocument()
    expect(screen.queryByText("Meets entry-zone criteria")).not.toBeInTheDocument()
    expect(container.textContent).not.toMatch(/\bBUY\b|\bSELL\b/i)
  })
})
