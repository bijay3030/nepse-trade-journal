import { fireEvent, screen, waitFor } from "@testing-library/react"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { DigestSettingsCard } from "./DigestSettingsCard"

const { mockGet, mockPatch } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPatch: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: mockGet, post: vi.fn(), patch: mockPatch } }))

const preferences = { enabled: true, sections: ["market", "entry_zone", "watchlist"], available_sections: ["market", "entry_zone", "watchlist"] }

describe("DigestSettingsCard", () => {
  beforeEach(() => {
    mockGet.mockResolvedValue({ data: preferences })
    mockPatch.mockImplementation((_path: string, changes: object) => Promise.resolve({ data: { ...preferences, ...changes } }))
  })

  it("saves a section being switched off", async () => {
    renderWithClient(<DigestSettingsCard />)

    fireEvent.click(await screen.findByRole("checkbox", { name: /Market summary/ }))

    await waitFor(() => expect(mockPatch).toHaveBeenCalledWith("/digest_preferences", { sections: ["entry_zone", "watchlist"] }))
    await waitFor(() => expect(screen.getByRole("checkbox", { name: /Market summary/ })).not.toBeChecked())
  })

  it("turns the digest off and disables the sections", async () => {
    renderWithClient(<DigestSettingsCard />)

    fireEvent.click(await screen.findByRole("checkbox", { name: "Build a daily digest" }))

    await waitFor(() => expect(mockPatch).toHaveBeenCalledWith("/digest_preferences", { enabled: false }))
    await waitFor(() => expect(screen.getByRole("checkbox", { name: /Watchlist status/ })).toBeDisabled())
  })
})
