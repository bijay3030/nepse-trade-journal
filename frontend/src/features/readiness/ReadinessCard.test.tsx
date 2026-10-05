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

  it("shows the broker flow component when the snapshot has one", () => {
    const base = readinessSnapshot()
    render(<ReadinessCard snapshot={{ ...base, readiness_components: { ...base.readiness_components, flow: { points: 12, max: 15 } } }} />)

    expect(screen.getByText("Broker flow")).toBeInTheDocument()
    expect(screen.getByText("12/15")).toBeInTheDocument()
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

  it("shows turnover and explains a guard that keeps the stock off the board", () => {
    render(<ReadinessCard snapshot={{ ...readinessSnapshot(), in_buy_zone: false, avg_turnover: 1_500_000, guards: ["thin_volume"] }} />)

    expect(screen.getByText("Thin volume")).toBeInTheDocument()
    expect(screen.getByText("NPR 1.5M")).toBeInTheDocument()
    expect(screen.getByText(/a small order can move the price.*Kept off the Entry zone now board/)).toBeInTheDocument()
    expect(screen.queryByText("Meets entry-zone criteria")).not.toBeInTheDocument()
  })

  it("shows the readiness history when there is one", () => {
    const history = [
      { traded_on: "2026-09-24", score: 48, zone_state: "too_early" as const, in_buy_zone: false },
      { traded_on: "2026-09-25", score: 61, zone_state: "in_zone" as const, in_buy_zone: true },
      { traded_on: "2026-09-28", score: 68, zone_state: "in_zone" as const, in_buy_zone: true },
    ]
    render(<ReadinessCard snapshot={readinessSnapshot()} history={history} />)

    expect(screen.getByText("Readiness, last 3 sessions")).toBeInTheDocument()
    expect(screen.getByRole("img", { name: "Readiness over 3 sessions: 48 to 68" })).toBeInTheDocument()
    expect(screen.getByText(/48 on 2026-09-24 → 68 now · dashed line at 60/)).toHaveTextContent("2 sessions met the entry-zone criteria")
  })

  it("shows the RS rating component on snapshots that have one", () => {
    const snapshot = readinessSnapshot()
    render(<ReadinessCard snapshot={{ ...snapshot, readiness_components: { ...snapshot.readiness_components, rs: { points: 15, max: 20 } } }} />)

    expect(screen.getByText("RS rating")).toBeInTheDocument()
    expect(screen.getByText("15/20")).toBeInTheDocument()
  })
})
