import { Input } from "../../components/ui"
import { riskReward, type LevelDraft } from "./levels"

const FIELDS: Array<{ key: keyof LevelDraft; label: string }> = [
  { key: "entry_zone_low", label: "Zone low" },
  { key: "entry_zone_high", label: "Zone high" },
  { key: "invalidation_price", label: "Invalidation" },
  { key: "stop_loss_price", label: "Stop loss" },
  { key: "target_price", label: "Target" },
]

export function LevelFields({ value, onChange, idPrefix }: { value: LevelDraft; onChange: (next: LevelDraft) => void; idPrefix: string }) {
  const rr = riskReward(value)
  return (
    <div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        {FIELDS.map((field) => (
          <label key={field.key} htmlFor={`${idPrefix}-${field.key}`} className="text-xs font-semibold text-slate">
            {field.label}
            <Input
              id={`${idPrefix}-${field.key}`}
              type="number"
              inputMode="decimal"
              step="0.01"
              min="0"
              className="mt-1 font-mono"
              value={value[field.key]}
              onChange={(event) => onChange({ ...value, [field.key]: event.target.value })}
            />
          </label>
        ))}
      </div>
      <p className="mt-2 text-xs text-slate">
        Risk:reward from the zone low: <span className="font-semibold text-ink">{rr === null ? "—" : `${rr}R`}</span>
      </p>
    </div>
  )
}
