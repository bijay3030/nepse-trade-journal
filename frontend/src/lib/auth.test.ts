import { vi } from "vitest"

import { authUrl, clearSession, getToken, saveSession } from "./auth"

describe("auth", () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    clearSession()
  })

  it("stores and clears the session", () => {
    saveSession("jwt-1", "me@example.com")
    expect(getToken()).toBe("jwt-1")
    clearSession()
    expect(getToken()).toBeNull()
  })

  it("puts /login on the API's origin when the API is on another host", () => {
    vi.stubEnv("VITE_API_BASE_URL", "https://api.example.com/api/v1")
    expect(authUrl("/login")).toBe("https://api.example.com/login")
    vi.stubEnv("VITE_API_BASE_URL", "/api/v1")
    expect(authUrl("/logout")).toBe("/logout")
  })

  it("sends the token with API requests", async () => {
    saveSession("jwt-2", "me@example.com")
    const { default: api } = await import("./axios")
    const handler = (api.interceptors.request as unknown as { handlers: Array<{ fulfilled: (config: { headers: Record<string, string> }) => { headers: Record<string, string> } }> }).handlers[0]

    expect(handler.fulfilled({ headers: {} }).headers.Authorization).toBe("Bearer jwt-2")
  })
})
