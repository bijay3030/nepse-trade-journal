import { fireEvent, screen, waitFor } from "@testing-library/react"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { BuyDialog } from "./BuyDialog"
import { defaultStop } from "./rules"

const { mockPost } = vi.hoisted(() => ({ mockPost: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: vi.fn(), post: mockPost } }))

const type = (label: string, value: string) => fireEvent.change(screen.getByLabelText(label), { target: { value } })

describe("defaultStop", () => {
  it("uses the setup's stop, capped at 8% below entry", () => {
    expect(defaultStop(100, 95)).toBe(95)
    expect(defaultStop(100, 80)).toBe(92)
    expect(defaultStop(100, null)).toBe(92)
  })
})

describe("BuyDialog", () => {
  beforeEach(() => mockPost.mockReset())

  it("previews the stop, risk and reward, then records the buy", async () => {
    mockPost.mockResolvedValue({ data: { quantity: 100, average_price: 505, stop_price: 470, target_price: 560, sellable_on: "2026-10-05" } })
    renderWithClient(<BuyDialog symbol="NABIL" currentPrice={505} watchlistItemId={7} setupStop={470} target={560} onClose={vi.fn()} />)

    expect(screen.getByRole("dialog", { name: "Mark NABIL as bought" })).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "Record buy" })).toBeDisabled()
    type("Quantity (shares)", "100")
    type("Date", "2026-10-01")

    expect(screen.getByText("470.00")).toBeInTheDocument()
    expect(screen.getByText("35.00")).toBeInTheDocument() // risk per share
    expect(screen.getByText("1.57R")).toBeInTheDocument()
    expect(screen.getByText("Rs 3,500.00")).toBeInTheDocument()

    fireEvent.click(screen.getByRole("button", { name: "Record buy" }))
    await waitFor(() => expect(mockPost).toHaveBeenCalledWith("/positions", { watchlist_item_id: 7, symbol: undefined, price: 505, quantity: 100, traded_on: "2026-10-01" }))
    expect(await screen.findByText(/Recorded: 100 NABIL at 505.00/)).toBeInTheDocument()
    expect(screen.getByText(/sellable from 2026-10-05 \(T\+2\)/)).toBeInTheDocument()
  })

  it("explains when the setup's stop is too far away and keeps an existing position's stop", () => {
    const { unmount } = renderWithClient(<BuyDialog symbol="NABIL" currentPrice={500} setupStop={400} target={null} onClose={vi.fn()} />)
    expect(screen.getByText("460.00")).toBeInTheDocument()
    expect(screen.getByText(/more than 8% below this price/)).toBeInTheDocument()
    unmount()

    renderWithClient(<BuyDialog symbol="NABIL" currentPrice={520} existingStop={480} target={600} onClose={vi.fn()} />)
    expect(screen.getByRole("dialog", { name: "Add a buy to NABIL" })).toBeInTheDocument()
    expect(screen.getByText("480.00")).toBeInTheDocument()
    expect(screen.getByText(/Your position's stop is kept/)).toBeInTheDocument()
  })

  it("rejects a fractional quantity", () => {
    renderWithClient(<BuyDialog symbol="NABIL" currentPrice={505} setupStop={470} onClose={vi.fn()} />)
    type("Quantity (shares)", "10.5")
    expect(screen.getByRole("button", { name: "Record buy" })).toBeDisabled()
  })
})
