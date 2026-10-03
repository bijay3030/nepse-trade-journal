import { fireEvent, screen, waitFor } from "@testing-library/react"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { TradingSettingsCard } from "./TradingSettingsCard"

const { mockGet, mockPatch } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPatch: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: mockGet, patch: mockPatch } }))

describe("TradingSettingsCard", () => {
  it("saves capital and risk, explaining the per-trade budget", async () => {
    mockGet.mockResolvedValue({ data: { trading_capital: null, risk_per_trade_pct: 1, max_open_risk_pct: 6 } })
    mockPatch.mockImplementation((_path: string, changes: object) => Promise.resolve({ data: changes }))
    renderWithClient(<TradingSettingsCard />)

    fireEvent.change(await screen.findByLabelText("Trading capital (Rs)"), { target: { value: "500000" } })
    expect(screen.getByText(/loses at most Rs 5,000, including fees/)).toBeInTheDocument()

    fireEvent.click(screen.getByRole("button", { name: "Save" }))
    await waitFor(() => expect(mockPatch).toHaveBeenCalledWith("/trading_settings", { trading_capital: 500000, risk_per_trade_pct: 1, max_open_risk_pct: 6 }))
    expect(await screen.findByText("Saved.")).toBeInTheDocument()
  })
})
