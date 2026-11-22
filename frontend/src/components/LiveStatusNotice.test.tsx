import { screen } from "@testing-library/react"
import { vi } from "vitest"

import { renderWithClient } from "../test/renderWithClient"
import { LiveStatusNotice } from "./LiveStatusNotice"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet } }))

describe("LiveStatusNotice", () => {
  it("says prices are live, from which source", async () => {
    mockGet.mockResolvedValue({ data: { state: "live", source: "sharesansar_live", as_of: "2026-11-23T12:40:00+05:45" } })
    renderWithClient(<LiveStatusNotice />)
    expect(await screen.findByLabelText("Price status")).toHaveTextContent(/Live prices from ShareSansar Live Trading, as of/)
    expect(mockGet).toHaveBeenCalledWith("/market/live_status")
  })

  it("warns when prices are delayed, why, and that alerts wait", async () => {
    mockGet.mockResolvedValue({ data: { state: "delayed", since: "2026-11-23T12:20:00+05:45", last_live_at: "2026-11-23T12:05:00+05:45",
      reasons: { sharesansar_live: "prices unchanged since 12:05", sharesansar_summary: "prices are for 2026-11-20, not today" } } })
    renderWithClient(<LiveStatusNotice />)
    const notice = await screen.findByRole("status", { name: "Price status" })
    expect(notice).toHaveTextContent(/Live prices are delayed since .*Prices shown are from .*alerts wait until fresh prices arrive/)
    expect(notice).toHaveTextContent("prices unchanged since 12:05 · prices are for 2026-11-20, not today")
  })

  it("shows nothing when the market is closed", async () => {
    mockGet.mockResolvedValue({ data: { state: "closed" } })
    const { container } = renderWithClient(<LiveStatusNotice />)
    await new Promise((resolve) => setTimeout(resolve, 20))
    expect(container).toBeEmptyDOMElement()
  })
})
