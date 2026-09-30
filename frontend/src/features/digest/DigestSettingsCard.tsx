import { Card, CardBody, CardHeader } from "../../components/ui"
import { useDigestPreferences, useUpdateDigestPreferences } from "./api"
import { SECTION_HELP, SECTION_LABELS } from "./labels"
import type { DigestSection } from "./types"

// Saved on the server (unlike the other settings on this page, which stay in this browser).
export function DigestSettingsCard() {
  const { data, isLoading, isError } = useDigestPreferences()
  const update = useUpdateDigestPreferences()

  const toggleSection = (section: DigestSection, on: boolean) => {
    if (!data) return
    const sections = on ? [...new Set([...data.sections, section])] : data.sections.filter((item) => item !== section)
    update.mutate({ sections })
  }

  return (
    <Card>
      <CardHeader title="Daily Digest" subtitle="Built after each close from the nightly snapshots. Saved to your account." />
      <CardBody className="space-y-3">
        {isLoading ? (
          <p className="text-sm text-slate">Loading…</p>
        ) : isError || !data ? (
          <p className="text-sm text-ember">Couldn't load your digest settings.</p>
        ) : (
          <>
            <label className="flex items-center justify-between rounded-xl border border-mist/70 bg-white/90 px-4 py-3">
              <span className="text-sm font-semibold text-ink">Build a daily digest</span>
              <input
                type="checkbox"
                checked={data.enabled}
                disabled={update.isPending}
                onChange={(event) => update.mutate({ enabled: event.target.checked })}
                className="h-4 w-4 accent-ink"
              />
            </label>
            <fieldset className="grid gap-3 md:grid-cols-3" disabled={!data.enabled || update.isPending}>
              <legend className="sr-only">Digest sections</legend>
              {data.available_sections.map((section) => (
                <label key={section} className="flex items-start justify-between gap-3 rounded-xl border border-mist/70 bg-white/90 px-4 py-3">
                  <span>
                    <span className="block text-sm font-semibold text-ink">{SECTION_LABELS[section]}</span>
                    <span className="block text-xs text-slate">{SECTION_HELP[section]}</span>
                  </span>
                  <input
                    type="checkbox"
                    checked={data.sections.includes(section)}
                    onChange={(event) => toggleSection(section, event.target.checked)}
                    className="mt-1 h-4 w-4 accent-ink"
                  />
                </label>
              ))}
            </fieldset>
            {update.isError && <p className="text-sm text-ember">Couldn't save. Try again.</p>}
            <p className="text-xs text-slate">Changes apply from the next digest, built after the next close (or run rails nepse:data:digest).</p>
          </>
        )}
      </CardBody>
    </Card>
  )
}
