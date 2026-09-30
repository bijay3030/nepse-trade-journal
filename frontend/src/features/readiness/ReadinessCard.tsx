import { CheckCircle2, XCircle } from "lucide-react"

import { Badge, Card, CardBody, CardHeader } from "../../components/ui"
import { cn } from "../../lib/cn"
import type { ReadinessSnapshot } from "../screener/types"
import { GuardBadges } from "./GuardBadges"
import { COMPONENT_LABELS, GUARD_DETAILS, SETUP_TYPE_LABELS, ZONE_LABELS, ZONE_TONE, formatTurnover, readinessTone } from "./labels"
import { ReadinessGauge } from "./ReadinessGauge"
import { ZoneLadder } from "./ZoneLadder"

const price = (value: number | null) => (value === null ? "—" : value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }))

export function ReadinessCard({ snapshot }: { snapshot: ReadinessSnapshot }) {
  const tone = readinessTone(snapshot.readiness_score)
  // Snapshots built before broker flow existed have no flow component.
  const components = (["trend", "setup", "market", "sector", "flow"] as const).flatMap((key) => {
    const component = snapshot.readiness_components[key]
    return component ? [{ key, ...component }] : []
  })
  const relative = snapshot.readiness_components.sector_vs_nepse

  return (
    <Card>
      <CardHeader title="Entry readiness" subtitle={`Rule checks on the ${snapshot.traded_on} close. Not a recommendation.`} />
      <CardBody>
        <div className="flex flex-wrap items-center gap-4">
          <ReadinessGauge score={snapshot.readiness_score} size={76} />
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={ZONE_TONE[snapshot.zone_state]}>{ZONE_LABELS[snapshot.zone_state]}</Badge>
              {snapshot.in_buy_zone && <Badge tone="gain">Meets entry-zone criteria</Badge>}
              <GuardBadges guards={snapshot.guards} />
              <span className={cn("text-sm font-semibold", tone.text)}>{tone.label} readiness</span>
            </div>
            <p className="mt-1 text-sm text-slate">
              {snapshot.setup_type ? SETUP_TYPE_LABELS[snapshot.setup_type] : "No setup"} · zone {price(snapshot.entry_zone_low)}–{price(snapshot.entry_zone_high)} ·
              invalidation {price(snapshot.invalidation_price)} · target {price(snapshot.target_price)}
            </p>
            <p className="text-sm text-slate">
              RS rating <b className="text-ink">{snapshot.rs_rating ?? "—"}</b> · trend rules <b className="text-ink">{snapshot.trend_rules_passed}/7</b>
              {snapshot.distance_to_zone_pct !== null && snapshot.zone_state === "too_early" && <> · {snapshot.distance_to_zone_pct.toFixed(2)}% below the zone</>}
              {snapshot.avg_turnover != null && <> · turnover <b className="text-ink">{formatTurnover(snapshot.avg_turnover)}</b>/day</>}
            </p>
            {snapshot.guards?.map((guard) => (
              <p key={guard} className="mt-1 text-xs text-ember">{GUARD_DETAILS[guard]} Kept off the Entry zone now board.</p>
            ))}
          </div>
        </div>

        <div className="mt-4">
          <ZoneLadder state={snapshot.zone_state} />
        </div>

        <div className="mt-5 grid gap-6 lg:grid-cols-2">
          <div>
            <h4 className="text-xs font-bold uppercase tracking-wide text-slate">Score breakdown</h4>
            <dl className="mt-2 space-y-2">
              {components.map((component) => (
                <div key={component.key} className="grid grid-cols-[8.5rem_1fr_3rem] items-center gap-2 text-sm">
                  <dt className="text-slate">{COMPONENT_LABELS[component.key]}</dt>
                  <dd className="h-2 rounded-full bg-slate/10" aria-hidden="true">
                    <div className="h-2 rounded-full bg-ink/70" style={{ width: `${(component.points / component.max) * 100}%` }} />
                  </dd>
                  <dd className="text-right font-mono text-ink">{component.points}/{component.max}</dd>
                </div>
              ))}
            </dl>
            {relative !== null && (
              <p className="mt-2 text-xs text-slate">Sector index {relative >= 0 ? "+" : ""}{relative.toFixed(2)} points vs NEPSE over 20 sessions.</p>
            )}
          </div>

          <div>
            <h4 className="text-xs font-bold uppercase tracking-wide text-slate">Trend template</h4>
            <ul className="mt-2 space-y-1.5">
              {snapshot.trend_checks.map((check) => (
                <li key={check.key} className="flex items-start gap-2 text-sm">
                  {check.passed ? (
                    <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-pine" aria-label="Met" />
                  ) : (
                    <XCircle className="mt-0.5 h-4 w-4 shrink-0 text-ember" aria-label="Not met" />
                  )}
                  <span className="min-w-0">
                    <span className="text-ink">{check.label}</span>
                    {check.detail && <span className="block text-xs text-slate">{check.detail}</span>}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </CardBody>
    </Card>
  )
}
