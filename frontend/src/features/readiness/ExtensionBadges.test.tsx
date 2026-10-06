import { render, screen } from "@testing-library/react"

import { ExtensionBadges } from "./ExtensionBadges"

describe("ExtensionBadges", () => {
  it("warns about an extended stock, a big move and a stale breakout", () => {
    render(<ExtensionBadges extension={{ extension_adr: 5.2, day_move_adr: 1.6, breakout_age: 6, flags: ["extended", "big_move", "stale_breakout"] }} />)

    expect(screen.getByText("Extended 5.2 ADR")).toHaveClass("bg-amber-100")
    expect(screen.getByText("Big move 1.6 ADR")).toBeInTheDocument()
    expect(screen.getByText("Stale breakout · day 6")).toHaveClass("bg-amber-100")
  })

  it("shows a fresh breakout's day neutrally and nothing for an ordinary stock", () => {
    const { container, rerender } = render(<ExtensionBadges extension={{ extension_adr: 1.2, day_move_adr: 0.4, breakout_age: 1, flags: [] }} />)
    expect(screen.getByText("Breakout day 1")).not.toHaveClass("bg-amber-100")

    rerender(<ExtensionBadges extension={{ extension_adr: 1.2, day_move_adr: 0.4, breakout_age: null, flags: [] }} />)
    expect(container).toBeEmptyDOMElement()
  })
})
