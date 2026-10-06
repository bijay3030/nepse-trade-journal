import axios from "axios"

import { clearSession, getToken, loginRequired } from "./auth"

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? "/api/v1",
  headers: {
    "Content-Type": "application/json",
  },
})

api.interceptors.request.use((config) => {
  const token = getToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// An expired or revoked token: sign in again.
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error?.response?.status === 401 && loginRequired()) {
      clearSession()
      if (window.location.pathname !== "/login") {
        window.location.assign(`/login?next=${encodeURIComponent(window.location.pathname + window.location.search)}`)
      }
    }
    return Promise.reject(error)
  },
)

export default api
