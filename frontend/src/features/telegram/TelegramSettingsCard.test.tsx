import { fireEvent, screen, waitFor } from "@testing-library/react"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { TelegramSettingsCard } from "./TelegramSettingsCard"

const { mockGet, mockPost, mockPatch, mockDelete } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPost: vi.fn(), mockPatch: vi.fn(), mockDelete: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: mockGet, post: mockPost, patch: mockPatch, delete: mockDelete } }))

const status = { configured: true, linked: false, username: null, pending: false, watchlist_alerts: true, board_alerts: true }
const linked = { ...status, linked: true, username: "trader" }

describe("TelegramSettingsCard", () => {
  beforeEach(() => {
    mockGet.mockReset()
    mockPost.mockReset()
    mockPatch.mockReset()
    mockDelete.mockReset()
  })

  it("explains how to set up the bot when the server has no token", async () => {
    mockGet.mockResolvedValue({ data: { ...status, configured: false } })
    renderWithClient(<TelegramSettingsCard />)

    expect(await screen.findByText(/Telegram isn't set up on the server yet/)).toBeInTheDocument()
    expect(screen.queryByRole("button", { name: "Connect Telegram" })).not.toBeInTheDocument()
  })

  it("connects: shows the one-time link, then checks until the chat is linked", async () => {
    mockGet.mockResolvedValue({ data: status })
    mockPost.mockImplementation((path: string) =>
      Promise.resolve({ data: path === "/telegram/link" ? { ...status, pending: true, link_url: "https://t.me/nepse_bot?start=abc" } : linked }),
    )
    renderWithClient(<TelegramSettingsCard />)

    fireEvent.click(await screen.findByRole("button", { name: "Connect Telegram" }))
    expect(await screen.findByRole("link", { name: "Open the bot in Telegram" })).toHaveAttribute("href", "https://t.me/nepse_bot?start=abc")

    fireEvent.click(screen.getByRole("button", { name: "I've pressed Start" }))
    expect(await screen.findByText(/Connected as @trader/)).toBeInTheDocument()
    expect(mockPost).toHaveBeenCalledWith("/telegram/check")
  })

  it("when linked, saves the message switches, sends a test and disconnects", async () => {
    mockGet.mockResolvedValue({ data: linked })
    mockPatch.mockImplementation((_path: string, changes: object) => Promise.resolve({ data: { ...linked, ...changes } }))
    mockPost.mockResolvedValue({ data: { ...linked, sent: true } })
    mockDelete.mockResolvedValue({ data: status })
    renderWithClient(<TelegramSettingsCard />)

    fireEvent.click(await screen.findByRole("checkbox", { name: /New on Entry zone now/ }))
    await waitFor(() => expect(mockPatch).toHaveBeenCalledWith("/telegram", { board_alerts: false }))
    await waitFor(() => expect(screen.getByRole("checkbox", { name: /New on Entry zone now/ })).not.toBeChecked())

    fireEvent.click(screen.getByRole("button", { name: "Send test message" }))
    expect(await screen.findByText("Test message sent.")).toBeInTheDocument()

    fireEvent.click(screen.getByRole("button", { name: "Disconnect" }))
    expect(await screen.findByRole("button", { name: "Connect Telegram" })).toBeInTheDocument()
  })

  it("shows the server's error", async () => {
    mockGet.mockResolvedValue({ data: status })
    mockPost.mockRejectedValue({ response: { data: { error: "Telegram getMe failed: Net::ReadTimeout" } } })
    renderWithClient(<TelegramSettingsCard />)

    fireEvent.click(await screen.findByRole("button", { name: "Connect Telegram" }))
    expect(await screen.findByText("Telegram getMe failed: Net::ReadTimeout")).toBeInTheDocument()
  })
})
