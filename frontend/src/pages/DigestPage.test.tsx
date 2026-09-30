import { screen, waitFor } from "@testing-library/react"
import { vi } from "vitest"

import { digestFixture } from "../features/digest/testData"
import { renderWithClient } from "../test/renderWithClient"
import { DigestPage } from "./DigestPage"

const { mockGet, mockPost } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPost: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet, post: mockPost, patch: vi.fn() } }))

describe("DigestPage", () => {
  beforeEach(() => {
    mockGet.mockReset()
    mockPost.mockReset().mockResolvedValue({ data: {} })
  })

  it("shows the latest digest and marks it read", async () => {
    mockGet.mockImplementation((path: string) =>
      Promise.resolve({ data: path === "/digests" ? { unread_count: 1, digests: [{ id: 1, traded_on: "2026-09-29", read_at: null, headline: "x" }] } : digestFixture() }),
    )
    renderWithClient(<DigestPage />)

    expect(await screen.findByText(/After the Tuesday, Sep 29 close · 1 new in the entry zone/)).toBeInTheDocument()
    expect(screen.getByText("Entry zone changes")).toBeInTheDocument()
    await waitFor(() => expect(mockPost).toHaveBeenCalledWith("/digests/2026-09-29/mark_read"))
  })

  it("explains when there is no digest yet", async () => {
    mockGet.mockImplementation((path: string) =>
      path === "/digests" ? Promise.resolve({ data: { unread_count: 0, digests: [] } }) : Promise.reject(new Error("404")),
    )
    renderWithClient(<DigestPage />)

    expect(await screen.findByText("No digest yet")).toBeInTheDocument()
    expect(mockPost).not.toHaveBeenCalled()
  })
})
