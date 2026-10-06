import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"

import { HeatWarning } from "./HeatWarning"

describe("HeatWarning", () => {
  it("warns when the buy goes over the limit and offers the size that fits", async () => {
    const onUse = vi.fn()
    render(<HeatWarning heat={{ now_pct: 5.2, after_pct: 6.4, limit_pct: 6, state: "over", fits_quantity: 80 }} onUse={onUse} />)

    expect(screen.getByLabelText("Portfolio heat")).toHaveTextContent("This buy takes open risk to 6.4% of capital (limit 6%, now 5.2%). 80 shares would stay within it Use 80.")
    await userEvent.click(screen.getByRole("button", { name: "Use 80" }))
    expect(onUse).toHaveBeenCalledWith(80)
  })

  it("stays quiet with room to spare", () => {
    const { container } = render(<HeatWarning heat={{ now_pct: 1, after_pct: 2, limit_pct: 6, state: "ok", fits_quantity: 100 }} />)
    expect(container).toBeEmptyDOMElement()
  })
})
