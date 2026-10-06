import { render, screen } from "@testing-library/react"

import { SignalBadges } from "./SignalBadges"

describe("SignalBadges", () => {
  it("shows the base count, warning at a late stage, and the volume signatures", () => {
    render(
      <SignalBadges
        signals={{ base_number: 3, in_base: true, base_partial: false, pocket_pivot_age: 2, up_down_ratio: 1.45, dry_up_days: 3,
          flags: ["late_stage_base", "pocket_pivot", "strong_up_down", "dry_up"] }}
      />,
    )

    expect(screen.getByText("Base 3 · late stage")).toHaveClass("bg-amber-100")
    expect(screen.getByText("Pocket pivot 2d ago")).toBeInTheDocument()
    expect(screen.getByText("U/D vol 1.45")).toBeInTheDocument()
    expect(screen.getByText("Volume dry-up")).toBeInTheDocument()
  })

  it("marks a partial count and hides an unremarkable up/down ratio", () => {
    render(<SignalBadges signals={{ base_number: 1, base_partial: true, up_down_ratio: 1.0, flags: [] }} />)

    expect(screen.getByText("Base 1+")).not.toHaveClass("bg-amber-100")
    expect(screen.queryByText(/U\/D vol/)).not.toBeInTheDocument()
  })
})
