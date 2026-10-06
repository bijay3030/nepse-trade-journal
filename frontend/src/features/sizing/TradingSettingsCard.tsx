import { useState } from "react"

import { Button, Card, CardBody, CardHeader, Input } from "../../components/ui"
import { apiErrorMessage } from "../watchlist/api"
import { useTradingSettings, useUpdateTradingSettings } from "./api"
import type { TradingSettings } from "./types"

function Form({ settings }: { settings: TradingSettings }) {
  const [capital, setCapital] = useState(settings.trading_capital === null ? "" : String(settings.trading_capital))
  const [risk, setRisk] = useState(String(settings.risk_per_trade_pct))
  const [maxRisk, setMaxRisk] = useState(String(settings.max_open_risk_pct))
  const [maxSector, setMaxSector] = useState(String(settings.max_sector_pct ?? 30))
  const update = useUpdateTradingSettings()
  const capitalValue = Number(capital)
  const budget = capitalValue > 0 && Number(risk) > 0 ? (capitalValue * Number(risk)) / 100 : null

  const save = () =>
    update.mutate({ trading_capital: capital === "" ? null : capitalValue, risk_per_trade_pct: Number(risk), max_open_risk_pct: Number(maxRisk), max_sector_pct: Number(maxSector) })

  return (
    <div className="space-y-3">
      <div className="grid gap-3 md:grid-cols-4">
        <label className="text-xs font-semibold text-slate">
          Trading capital (Rs)
          <Input className="mt-1" type="number" min="0" step="1000" value={capital} onChange={(event) => setCapital(event.target.value)} placeholder="e.g. 500000" />
        </label>
        <label className="text-xs font-semibold text-slate">
          Risk per trade (% of capital)
          <Input className="mt-1" type="number" min="0.1" max="10" step="0.1" value={risk} onChange={(event) => setRisk(event.target.value)} />
        </label>
        <label className="text-xs font-semibold text-slate">
          Max open risk (% of capital)
          <Input className="mt-1" type="number" min="1" max="50" step="0.5" value={maxRisk} onChange={(event) => setMaxRisk(event.target.value)} />
        </label>
        <label className="text-xs font-semibold text-slate">
          Max per sector (% of capital)
          <Input className="mt-1" type="number" min="5" max="100" step="5" value={maxSector} onChange={(event) => setMaxSector(event.target.value)} />
        </label>
      </div>
      <p className="text-xs text-slate">
        {budget !== null
          ? `Each trade is sized so hitting its stop loses at most Rs ${budget.toLocaleString("en-US", { maximumFractionDigits: 0 })}, including fees.`
          : "Enter your capital to get position sizes on watchlist cards and when marking a buy."}{" "}
        Max open risk caps the total you can lose if every stop is hit at once; the sector limit flags concentration on the Positions page.
      </p>
      {update.isError && <p role="alert" className="text-sm text-ember">{apiErrorMessage(update.error)}</p>}
      {update.isSuccess && <p className="text-sm text-pine">Saved.</p>}
      <Button size="sm" onClick={save} disabled={update.isPending}>{update.isPending ? "Saving…" : "Save"}</Button>
    </div>
  )
}

// Capital and risk limits for position sizing. Saved to the account.
export function TradingSettingsCard() {
  const { data, isLoading, isError } = useTradingSettings()
  return (
    <Card>
      <CardHeader title="Capital & Risk" subtitle="Used to size positions and limit total risk. Saved to your account." />
      <CardBody>
        {isLoading ? <p className="text-sm text-slate">Loading…</p> : isError || !data ? <p className="text-sm text-ember">Couldn't load your settings.</p> : <Form settings={data} />}
      </CardBody>
    </Card>
  )
}
