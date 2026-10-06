import { render, screen } from "@testing-library/react"

import { HeatCard, SectorCard } from "./PortfolioCards"
import type { Portfolio } from "./types"

const portfolio: Portfolio = {
  capital: 1_000_000, open_risk: 72_000, market_value: 480_000, invested: 470_000, cash: 530_000,
  heat: { pct: 7.2, limit_pct: 6, state: "over", room: 0 },
  positions: [
    { position_id: 1, symbol: "NABIL", open_risk: 50_000, heat_pct: 5, share_of_risk_pct: 69.4 },
    { position_id: 2, symbol: "UPPER", open_risk: 22_000, heat_pct: 2.2, share_of_risk_pct: 30.6 },
  ],
  sectors: [
    { sector: "Commercial Banks", value: 380_000, pct: 38, symbols: ["NABIL"], over: true },
    { sector: "Hydropower", value: 100_000, pct: 10, symbols: ["UPPER"], over: false },
  ],
}

describe("Portfolio cards", () => {
  it("shows heat over the limit with each position's share", () => {
    render(<HeatCard portfolio={portfolio} />)

    expect(screen.getByText("7.2% of capital at risk · limit 6%")).toHaveClass("text-ember")
    expect(screen.getByText(/Rs 72,000 lost if every stop is hit, after costs\. New entries would add to risk over your limit\. Cash Rs 530,000/)).toBeInTheDocument()
    expect(screen.getByLabelText("Heat by position")).toHaveTextContent("NABIL 5.0% (69% of risk)")
  })

  it("asks for capital when heat can't be measured", () => {
    render(<HeatCard portfolio={{ ...portfolio, capital: null, cash: null, heat: { pct: null, limit_pct: 6, state: "unknown", room: null } }} />)
    expect(screen.getByText(/Set your trading capital in Settings/)).toBeInTheDocument()
  })

  it("flags a sector over the limit", () => {
    render(<SectorCard portfolio={portfolio} limit={30} />)

    expect(screen.getByText("38.0%")).toHaveClass("text-ember")
    expect(screen.getByText(/Over your 30% sector limit/)).toBeInTheDocument()
    expect(screen.getAllByText(/Over your/)).toHaveLength(1)
  })
})
