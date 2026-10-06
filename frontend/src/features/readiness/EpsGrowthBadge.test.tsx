import { render, screen } from "@testing-library/react"

import { EpsGrowthBadge } from "./EpsGrowthBadge"

describe("EpsGrowthBadge", () => {
  it("highlights 25%+ growth and explains its source", () => {
    render(<EpsGrowthBadge growth={{ growth_pct: 35, source: "reported", fiscal_year: "082/083", quarter: "Q4", eps: 27, prior_eps: 20, strong: true }} />)

    const badge = screen.getByText("EPS +35% YoY")
    expect(badge).toHaveClass("text-pine")
    expect(badge).toHaveAttribute("title", expect.stringContaining("EPS 27 vs 20 in the same quarter a year earlier"))
  })

  it("marks a decline and says when the figure comes from Chukul", () => {
    render(<EpsGrowthBadge growth={{ growth_pct: -12.4, source: "chukul", fiscal_year: "082/083", quarter: "Q4", eps: 9, prior_eps: null, strong: false }} />)

    expect(screen.getByText("EPS -12.4% YoY")).toHaveClass("text-ember")
    expect(screen.getByText("EPS -12.4% YoY")).toHaveAttribute("title", expect.stringContaining("growth rate reported by Chukul"))
  })
})
