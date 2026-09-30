import { render, screen } from "@testing-library/react"

import { BookCloseBadge } from "./BookCloseBadge"
import { CorporateActionsCard } from "./CorporateActionsCard"
import { bookCloseText } from "./format"
import type { BookClose } from "./types"

const bonus: BookClose = { fiscal_year: "082/083", book_close_on: "2026-10-02", days_until: 2, cash_percent: 5, bonus_percent: 10, agm_on: "2026-10-14" }
const cashOnly: BookClose = { ...bonus, bonus_percent: 0, cash_percent: 12 }

describe("corporate actions", () => {
  it("describes a book close with its entitlements", () => {
    expect(bookCloseText(bonus)).toBe("Book close Oct 2 · 10% bonus, 5% cash")
    expect(bookCloseText(cashOnly)).toBe("Book close Oct 2 · 12% cash")
  })

  it("highlights bonus book closes", () => {
    render(<BookCloseBadge bookClose={bonus} />)

    expect(screen.getByText("Book close Oct 2 · 10% bonus, 5% cash")).toHaveClass("bg-amber-100")
  })

  it("shows the upcoming book close, the price adjustment and the history", () => {
    render(
      <CorporateActionsCard
        upcoming={bonus}
        history={[{ fiscal_year: "082/083", cash_percent: 5, bonus_percent: 10, total_percent: 15, book_close_on: "2026-10-02", agm_on: "2026-10-14" }]}
      />,
    )

    expect(screen.getByText("Book close Oct 2, 2026 (in 2 days), FY 082/083")).toBeInTheDocument()
    expect(screen.getByText(/divided by 1.10/)).toBeInTheDocument()
    expect(screen.getByRole("cell", { name: "10%" })).toBeInTheDocument()
  })

  it("says when nothing is announced", () => {
    render(<CorporateActionsCard upcoming={null} history={[]} />)

    expect(screen.getByText("No book close announced in the next 45 days.")).toBeInTheDocument()
  })
})
