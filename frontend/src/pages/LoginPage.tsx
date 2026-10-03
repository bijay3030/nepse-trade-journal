import axios from "axios"
import { type FormEvent, useState } from "react"
import { Navigate, useNavigate, useSearchParams } from "react-router-dom"

import { Button, Card, Input } from "../components/ui"
import { authUrl, getToken, saveSession } from "../lib/auth"

// Signs in with the account's email and password; the API returns a JWT.
export function LoginPage() {
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [params] = useSearchParams()
  const navigate = useNavigate()
  const next = params.get("next")?.startsWith("/") ? (params.get("next") as string) : "/dashboard"

  if (getToken()) return <Navigate to={next} replace />

  const submit = async (event: FormEvent) => {
    event.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { data } = await axios.post<{ token: string; user: { email: string } }>(authUrl("/login"), { user: { email, password } })
      saveSession(data.token, data.user.email)
      navigate(next, { replace: true })
    } catch (failure) {
      const status = axios.isAxiosError(failure) ? failure.response?.status : undefined
      setError(status === 401 ? "Wrong email or password." : "Couldn't reach the server. Try again.")
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-mist/40 px-4">
      <Card className="w-full max-w-sm p-6">
        <h1 className="font-display text-2xl font-bold text-ink">NEPSE Trade Journal</h1>
        <p className="mt-1 text-sm text-slate">Sign in to continue.</p>
        <form className="mt-5 space-y-3" onSubmit={(event) => void submit(event)}>
          <label className="block text-xs font-semibold text-slate">
            Email
            <Input className="mt-1" type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} />
          </label>
          <label className="block text-xs font-semibold text-slate">
            Password
            <Input className="mt-1" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} />
          </label>
          {error && <p role="alert" className="text-sm text-ember">{error}</p>}
          <Button type="submit" className="w-full" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</Button>
        </form>
      </Card>
    </div>
  )
}
