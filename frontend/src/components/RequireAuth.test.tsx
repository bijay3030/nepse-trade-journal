import { render, screen } from "@testing-library/react"
import { MemoryRouter, Route, Routes } from "react-router-dom"
import { vi } from "vitest"

import { clearSession, saveSession } from "../lib/auth"
import { RequireAuth } from "./RequireAuth"

function renderAt(route: string) {
  return render(
    <MemoryRouter initialEntries={[route]}>
      <Routes>
        <Route path="/login" element={<p>Login page</p>} />
        <Route path="/positions" element={<RequireAuth><p>Positions page</p></RequireAuth>} />
      </Routes>
    </MemoryRouter>,
  )
}

describe("RequireAuth", () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    clearSession()
  })

  it("sends visitors without a session to the login page when login is required", () => {
    vi.stubEnv("VITE_REQUIRE_LOGIN", "true")
    renderAt("/positions")
    expect(screen.getByText("Login page")).toBeInTheDocument()
  })

  it("shows the page with a session, or in development without one", () => {
    vi.stubEnv("VITE_REQUIRE_LOGIN", "true")
    saveSession("jwt", "me@example.com")
    const { unmount } = renderAt("/positions")
    expect(screen.getByText("Positions page")).toBeInTheDocument()
    unmount()

    clearSession()
    vi.stubEnv("VITE_REQUIRE_LOGIN", "false")
    renderAt("/positions")
    expect(screen.getByText("Positions page")).toBeInTheDocument()
  })
})
