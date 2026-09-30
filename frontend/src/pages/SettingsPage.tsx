import { useEffect, useRef, useState } from "react"
import { Controller, useForm } from "react-hook-form"
import { Download, Trash2, Upload } from "lucide-react"
import { Badge, Button, Card, CardBody, CardHeader, Input, Select } from "../components/ui"
import { DigestSettingsCard } from "../features/digest/DigestSettingsCard"
import { TelegramSettingsCard } from "../features/telegram/TelegramSettingsCard"

type SettingsFormValues = {
  name: string
  email: string
  phone: string
  currentPassword: string
  newPassword: string
  avatar: FileList | null
  riskPerTrade: number
  preferredBroker: string
  defaultStrategy: string
  positionSizingMethod: "risk_based" | "fixed_amount"
  emailNotifications: boolean
  alertEmail: boolean
  alertPush: boolean
  alertInApp: boolean
  dailySummaryTime: string
  weeklyReportDay: string
  theme: "light" | "dark" | "system"
  numberFormat: "nepali" | "english"
  defaultDashboardView: "overview" | "analytics" | "portfolio"
  deleteConfirm: string
}

const SETTINGS_KEY = "platform_settings_v1"
const TRADES_KEY = "trades_records_v1"

function Toggle({
  label,
  checked,
  onChange,
}: {
  label: string
  checked: boolean
  onChange: (checked: boolean) => void
}) {
  return (
    <label className="flex items-center justify-between rounded-xl border border-mist/70 bg-white/90 px-4 py-3">
      <span className="text-sm font-semibold text-ink">{label}</span>
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="h-4 w-4 accent-ink" />
    </label>
  )
}

function downloadFile(filename: string, content: string, type: string) {
  const blob = new Blob([content], { type })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

function parseCsvToObjects(csv: string) {
  const lines = csv.trim().split(/\r?\n/)
  if (lines.length < 2) return []
  const headers = lines[0].split(",").map((h) => h.trim())
  return lines.slice(1).map((line) => {
    const values = line.split(",").map((v) => v.trim())
    return headers.reduce<Record<string, string>>((acc, key, idx) => {
      acc[key] = values[idx] ?? ""
      return acc
    }, {})
  })
}

export function SettingsPage() {
  const [toast, setToast] = useState<string | null>(null)
  const [avatarName, setAvatarName] = useState<string>("")
  const importRef = useRef<HTMLInputElement | null>(null)

  const {
    register,
    handleSubmit,
    control,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<SettingsFormValues>({
    defaultValues: {
      name: "Aarav Shrestha",
      email: "aarav@example.com",
      phone: "9800000000",
      currentPassword: "",
      newPassword: "",
      avatar: null,
      riskPerTrade: 2,
      preferredBroker: "ABC Securities",
      defaultStrategy: "",
      positionSizingMethod: "risk_based",
      emailNotifications: true,
      alertEmail: true,
      alertPush: false,
      alertInApp: true,
      dailySummaryTime: "20:00",
      weeklyReportDay: "Sunday",
      theme: "system",
      numberFormat: "english",
      defaultDashboardView: "overview",
      deleteConfirm: "",
    },
  })

  useEffect(() => {
    const raw = localStorage.getItem(SETTINGS_KEY)
    if (!raw) return
    try {
      const saved = JSON.parse(raw) as Partial<SettingsFormValues>
      Object.entries(saved).forEach(([key, value]) => {
        if (key === "avatar") return
        setValue(key as keyof SettingsFormValues, value as never)
      })
    } catch {
      // Ignore malformed settings.
    }
  }, [setValue])

  useEffect(() => {
    if (!toast) return
    const t = window.setTimeout(() => setToast(null), 2200)
    return () => window.clearTimeout(t)
  }, [toast])

  const onSubmit = async (values: SettingsFormValues) => {
    const payload = { ...values, avatar: undefined, currentPassword: undefined, newPassword: undefined }
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(payload))
    setToast("Settings saved successfully")
  }

  const exportJson = () => {
    const data = localStorage.getItem(TRADES_KEY) ?? "[]"
    downloadFile("trades-export.json", data, "application/json")
  }

  const exportCsv = () => {
    const json = JSON.parse(localStorage.getItem(TRADES_KEY) ?? "[]") as Array<Record<string, unknown>>
    if (json.length === 0) {
      downloadFile("trades-export.csv", "id,symbol,side,qty,price,pnl\n", "text/csv")
      return
    }
    const headers = Object.keys(json[0])
    const rows = json.map((row) =>
      headers
        .map((h) => String((row[h] ?? "")).replaceAll(",", " "))
        .join(","),
    )
    const csv = [headers.join(","), ...rows].join("\n")
    downloadFile("trades-export.csv", csv, "text/csv")
  }

  const onImportTrades = async (file: File) => {
    const text = await file.text()
    if (file.name.toLowerCase().endsWith(".json")) {
      JSON.parse(text)
      localStorage.setItem(TRADES_KEY, text)
      setToast("Trades imported from JSON")
      return
    }
    const parsed = parseCsvToObjects(text)
    localStorage.setItem(TRADES_KEY, JSON.stringify(parsed))
    setToast("Trades imported from CSV")
  }

  const deleteAccount = () => {
    if (watch("deleteConfirm") !== "DELETE") {
      setToast("Type DELETE to confirm account deletion")
      return
    }
    localStorage.removeItem(SETTINGS_KEY)
    localStorage.removeItem(TRADES_KEY)
    setToast("Account deleted (mock)")
  }

  return (
    <div className="space-y-5">
      {toast ? (
        <div className="fixed right-5 top-5 z-50 rounded-xl bg-ink px-4 py-3 text-sm font-semibold text-white shadow-panel">{toast}</div>
      ) : null}

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
        <Card>
          <CardHeader title="Profile Settings" />
          <CardBody className="grid gap-3 md:grid-cols-2">
            <div>
              <Input placeholder="Full name" {...register("name", { required: "Name is required", minLength: 2 })} />
              {errors.name ? <p className="mt-1 text-xs text-ember">{errors.name.message}</p> : null}
            </div>
            <div>
              <Input
                placeholder="Email"
                type="email"
                {...register("email", {
                  required: "Email is required",
                  pattern: { value: /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/, message: "Enter a valid email" },
                })}
              />
              {errors.email ? <p className="mt-1 text-xs text-ember">{errors.email.message}</p> : null}
            </div>
            <div>
              <Input
                placeholder="Phone"
                {...register("phone", { required: "Phone is required", pattern: { value: /^[0-9+\\-\\s]{7,15}$/, message: "Enter a valid phone number" } })}
              />
              {errors.phone ? <p className="mt-1 text-xs text-ember">{errors.phone.message}</p> : null}
            </div>
            <div>
              <Input placeholder="Current password" type="password" {...register("currentPassword")} />
            </div>
            <div>
              <Input
                placeholder="New password"
                type="password"
                {...register("newPassword", { validate: (v) => !v || v.length >= 8 || "Min 8 chars if changing password" })}
              />
              {errors.newPassword ? <p className="mt-1 text-xs text-ember">{errors.newPassword.message}</p> : null}
            </div>
            <div>
              <Input
                type="file"
                accept="image/*"
                {...register("avatar")}
                onChange={(e) => {
                  const file = e.target.files?.[0]
                  setAvatarName(file?.name ?? "")
                }}
              />
              <p className="mt-1 text-xs text-slate/75">{avatarName ? `Selected: ${avatarName}` : "Avatar upload optional"}</p>
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Trading Preferences" />
          <CardBody className="grid gap-3 md:grid-cols-2">
            <div>
              <Input
                type="number"
                step="0.1"
                min="1"
                max="5"
                placeholder="Risk % per trade"
                {...register("riskPerTrade", { valueAsNumber: true, min: 1, max: 5 })}
              />
              <p className="mt-1 text-xs text-slate/75">Default risk per trade: 1% to 5%</p>
            </div>
            <Select {...register("preferredBroker")}>
              <option>ABC Securities</option>
              <option>Prabhu Capital</option>
              <option>Global IME Securities</option>
              <option>Kumari Securities</option>
            </Select>
            <Input placeholder="Default strategy (optional)" {...register("defaultStrategy")} />
            <Select {...register("positionSizingMethod")}>
              <option value="risk_based">Risk-based</option>
              <option value="fixed_amount">Fixed amount</option>
            </Select>
          </CardBody>
        </Card>

        <TelegramSettingsCard />

        <DigestSettingsCard />

        <Card>
          <CardHeader title="Notification Settings" />
          <CardBody className="space-y-3">
            <Controller
              name="emailNotifications"
              control={control}
              render={({ field }) => <Toggle label="Email notifications" checked={field.value} onChange={field.onChange} />}
            />
            <div className="grid gap-3 md:grid-cols-3">
              <Controller name="alertEmail" control={control} render={({ field }) => <Toggle label="Price Alerts by Email" checked={field.value} onChange={field.onChange} />} />
              <Controller name="alertPush" control={control} render={({ field }) => <Toggle label="Price Alerts by Push" checked={field.value} onChange={field.onChange} />} />
              <Controller name="alertInApp" control={control} render={({ field }) => <Toggle label="Price Alerts In-app" checked={field.value} onChange={field.onChange} />} />
            </div>
            <div className="grid gap-3 md:grid-cols-2">
              <label className="text-sm font-semibold text-slate">
                Daily summary email time
                <Input type="time" className="mt-1" {...register("dailySummaryTime")} />
              </label>
              <label className="text-sm font-semibold text-slate">
                Weekly report day
                <Select className="mt-1" {...register("weeklyReportDay")}>
                  <option>Sunday</option>
                  <option>Monday</option>
                  <option>Tuesday</option>
                  <option>Wednesday</option>
                  <option>Thursday</option>
                  <option>Friday</option>
                  <option>Saturday</option>
                </Select>
              </label>
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Display Settings" />
          <CardBody className="grid gap-3 md:grid-cols-3">
            <label className="text-sm font-semibold text-slate">
              Theme
              <Select className="mt-1" {...register("theme")}>
                <option value="light">Light</option>
                <option value="dark">Dark</option>
                <option value="system">System</option>
              </Select>
            </label>
            <label className="text-sm font-semibold text-slate">
              Number format
              <Select className="mt-1" {...register("numberFormat")}>
                <option value="english">English</option>
                <option value="nepali">Nepali</option>
              </Select>
            </label>
            <label className="text-sm font-semibold text-slate">
              Default dashboard view
              <Select className="mt-1" {...register("defaultDashboardView")}>
                <option value="overview">Overview</option>
                <option value="analytics">Analytics</option>
                <option value="portfolio">Portfolio</option>
              </Select>
            </label>
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Data Management" />
          <CardBody className="space-y-4">
            <div className="flex flex-wrap gap-2">
              <Button type="button" variant="secondary" onClick={exportJson}>
                <Download className="mr-2 h-4 w-4" />
                Export JSON
              </Button>
              <Button type="button" variant="secondary" onClick={exportCsv}>
                <Download className="mr-2 h-4 w-4" />
                Export CSV
              </Button>
              <Button type="button" variant="ghost" onClick={() => importRef.current?.click()}>
                <Upload className="mr-2 h-4 w-4" />
                Import Trades
              </Button>
              <input
                ref={importRef}
                type="file"
                accept=".json,.csv"
                className="hidden"
                onChange={async (e) => {
                  const file = e.target.files?.[0]
                  if (!file) return
                  try {
                    await onImportTrades(file)
                  } catch {
                    setToast("Import failed. Use valid JSON/CSV.")
                  } finally {
                    e.target.value = ""
                  }
                }}
              />
            </div>

            <div className="rounded-xl border border-ember/40 bg-ember/5 p-4">
              <p className="text-sm font-semibold text-ember">Delete Account</p>
              <p className="mt-1 text-xs text-slate/80">This action is irreversible. Type DELETE to confirm.</p>
              <div className="mt-3 flex flex-wrap gap-2">
                <Input className="max-w-xs" placeholder="Type DELETE" {...register("deleteConfirm")} />
                <Button type="button" variant="ghost" className="text-ember" onClick={deleteAccount}>
                  <Trash2 className="mr-2 h-4 w-4" />
                  Delete Account
                </Button>
              </div>
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Billing (Future)" />
          <CardBody className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <p className="text-sm font-semibold text-ink">Current Plan: Free</p>
              <p className="text-xs text-slate/80">Advanced analytics and broker integrations coming soon.</p>
            </div>
            <Badge variant="neutral">Future</Badge>
            <Button type="button" variant="secondary">
              Upgrade
            </Button>
          </CardBody>
        </Card>

        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={() => window.location.reload()}>
            Reset
          </Button>
          <Button type="submit" disabled={isSubmitting}>
            Save Settings
          </Button>
        </div>
      </form>
    </div>
  )
}
