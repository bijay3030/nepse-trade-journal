import { fireEvent, render, screen, waitFor } from "@testing-library/react"
import { MemoryRouter, Route, Routes } from "react-router-dom"
import { vi } from "vitest"

import { clearSession, getEmail, getToken } from "../lib/auth"
import { LoginPage } from "./LoginPage"

const { mockPost } = vi.hoisted(() => ({ mockPost: vi.fn() }))
vi.mock("axios", async (original) => {
  const actual = await original<typeof import("axios")>()
  return { default: { ...actual.default, post: mockPost, isAxiosError: actual.default.isAxiosError } }
})

function renderLogin(route = "/login?next=/positions") {
  return render(
    <MemoryRouter initialEntries={[route]}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/positions" element={<p>Positions page</p>} />
      </Routes>
    </MemoryRouter>,
  )
}

const fill = () => {
  fireEvent.change(screen.getByLabelText("Email"), { target: { value: "me@example.com" } })
  fireEvent.change(screen.getByLabelText("Password"), { target: { value: "s3cret-pass" } })
  fireEvent.click(screen.getByRole("button", { name: "Sign in" }))
}

describe("LoginPage", () => {
  beforeEach(() => {
    clearSession()
    mockPost.mockReset()
  })

  it("signs in, stores the session and goes to the requested page", async () => {
    mockPost.mockResolvedValue({ data: { token: "jwt-123", user: { email: "me@example.com" } } })
    renderLogin()
    fill()

    expect(await screen.findByText("Positions page")).toBeInTheDocument()
    expect(mockPost).toHaveBeenCalledWith("/login", { user: { email: "me@example.com", password: "s3cret-pass" } })
    expect(getToken()).toBe("jwt-123")
    expect(getEmail()).toBe("me@example.com")
  })

  it("says when the email or password is wrong", async () => {
    mockPost.mockRejectedValue(Object.assign(new Error("401"), { isAxiosError: true, response: { status: 401 } }))
    renderLogin()
    fill()

    expect(await screen.findByRole("alert")).toHaveTextContent("Wrong email or password.")
    expect(getToken()).toBeNull()
  })

  it("ignores a next= that leaves the app", async () => {
    mockPost.mockResolvedValue({ data: { token: "jwt-123", user: { email: "me@example.com" } } })
    render(
      <MemoryRouter initialEntries={["/login?next=https://evil.example"]}>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/dashboard" element={<p>Dashboard</p>} />
        </Routes>
      </MemoryRouter>,
    )
    fill()

    await waitFor(() => expect(screen.getByText("Dashboard")).toBeInTheDocument())
  })
})
