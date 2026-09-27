import { screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { PlanFromSetup } from "./PlanFromSetup"
import { positionSize } from "./sizing"
import { watchlistItem } from "./testData"

const { mockGet, mockPost } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPost: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: mockGet, post: mockPost } }))

describe("positionSize", () => {
  it("sizes the position so a stop-out loses the chosen share of capital", () => {
    expect(positionSize(1_000_000, 1, 570, 548)).toBe(454) // 10,000 / 22
    expect(positionSize(1_000_000, 1, 548, 570)).toBeNull()
    expect(positionSize(0, 1, 570, 548)).toBeNull()
  })
})

describe("PlanFromSetup", () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockGet.mockResolvedValue({ data: [watchlistItem()] })
    mockPost.mockResolvedValue({ data: { trade_plan_id: 42, watchlist_item: watchlistItem({ status: "planned", trade_plan_id: 42 }) } })
  })

  it("prefills the plan from the setup, sizes it and saves it", async () => {
    // After saving, the refetched item carries the plan id; the confirmation must still show.
    let saved = false
    mockGet.mockImplementation(() => Promise.resolve({ data: [saved ? watchlistItem({ status: "planned", trade_plan_id: 42 }) : watchlistItem()] }))
    mockPost.mockImplementation(() => {
      saved = true
      return Promise.resolve({ data: { trade_plan_id: 42, watchlist_item: watchlistItem({ status: "planned", trade_plan_id: 42 }) } })
    })
    renderWithClient(<PlanFromSetup itemId={7} />)

    expect(await screen.findByLabelText("Planned entry")).toHaveValue(570)
    expect(screen.getByLabelText("Stop loss")).toHaveValue(548)
    expect(screen.getByLabelText("Target")).toHaveValue(640)
    expect(screen.getByLabelText("Strategy")).toHaveValue("Turtle Breakout")

    await userEvent.type(screen.getByLabelText("Account size (NPR)"), "1000000")
    expect(screen.getByText("454 shares")).toBeInTheDocument()

    await userEvent.click(screen.getByRole("button", { name: "Save plan" }))

    expect(mockPost).toHaveBeenCalledWith("/watchlist_items/7/trade_plan", expect.objectContaining({
      planned_entry_price: 570, stop_loss_price: 548, target_price: 640, planned_quantity: 454, strategy: "Turtle Breakout",
    }))
    expect(await screen.findByText("Plan #42 saved for NABIL")).toBeInTheDocument()
  })

  it("does not create a second plan for the same setup", async () => {
    mockGet.mockResolvedValue({ data: [watchlistItem({ trade_plan_id: 42, status: "planned" })] })
    renderWithClient(<PlanFromSetup itemId={7} />)

    expect(await screen.findByText("A plan (#42) already exists for this setup.")).toBeInTheDocument()
  })
})
