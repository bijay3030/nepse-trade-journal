import type { ReactNode } from "react"
import { Navigate, useLocation } from "react-router-dom"

import { getToken, loginRequired } from "../lib/auth"

// Sends visitors without a session to /login (production; optional in development).
export function RequireAuth({ children }: { children: ReactNode }) {
  const location = useLocation()
  if (loginRequired() && !getToken()) {
    return <Navigate to={`/login?next=${encodeURIComponent(location.pathname + location.search)}`} replace />
  }
  return <>{children}</>
}
