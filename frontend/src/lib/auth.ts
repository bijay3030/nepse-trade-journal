// The API session: a JWT from POST /login, kept in this browser.
const TOKEN_KEY = "nepse_auth_token"
const EMAIL_KEY = "nepse_auth_email"

function read(key: string) {
  try {
    return window.localStorage.getItem(key)
  } catch {
    return null
  }
}

function write(key: string, value: string | null) {
  try {
    if (value === null) window.localStorage.removeItem(key)
    else window.localStorage.setItem(key, value)
  } catch {
    // Storage blocked (private mode): the session lasts until the tab closes.
  }
}

export const getToken = () => read(TOKEN_KEY)
export const getEmail = () => read(EMAIL_KEY)

export function saveSession(token: string, email: string) {
  write(TOKEN_KEY, token)
  write(EMAIL_KEY, email)
}

export function clearSession() {
  write(TOKEN_KEY, null)
  write(EMAIL_KEY, null)
}

/**
 * Production needs a login. In development the API signs requests without a
 * token in as the first user, so the login page is optional there.
 */
export const loginRequired = () => import.meta.env.PROD || import.meta.env.VITE_REQUIRE_LOGIN === "true"

/** Where /login and /logout live: the API's origin (they're outside /api/v1). */
export function authUrl(path: "/login" | "/logout") {
  const base = import.meta.env.VITE_API_BASE_URL
  if (!base || !/^https?:\/\//.test(base)) return path
  return `${new URL(base).origin}${path}`
}
