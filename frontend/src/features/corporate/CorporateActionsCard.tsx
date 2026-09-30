import { format, parseISO } from "date-fns"

import { Card, CardBody, CardHeader } from "../../components/ui"
import type { BookClose, DividendRow } from "./types"

const pct = (value: number | null) => (value === null || value === 0 ? "—" : `${value}%`)
const day = (value: string | null) => (value ? format(parseISO(value), "MMM d, yyyy") : "—")

export function CorporateActionsCard({ upcoming, history }: { upcoming: BookClose | null; history: DividendRow[] }) {
  return (
    <Card>
      <CardHeader title="Corporate actions" subtitle="Book closes, cash dividends and bonus shares" />
      <CardBody>
        {upcoming ? (
          <div className={upcoming.bonus_percent ? "rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900" : "rounded-lg bg-slate/5 px-3 py-2 text-sm text-ink"}>
            <p className="font-semibold">
              Book close {day(upcoming.book_close_on)} ({upcoming.days_until === 0 ? "today" : `in ${upcoming.days_until} days`}), FY {upcoming.fiscal_year}
            </p>
            <p>
              {[upcoming.bonus_percent ? `${upcoming.bonus_percent}% bonus` : null, upcoming.cash_percent ? `${upcoming.cash_percent}% cash` : null].filter(Boolean).join(" and ") || "Entitlement not announced"}
              {upcoming.agm_on && <> · AGM {day(upcoming.agm_on)}</>}
            </p>
            {Boolean(upcoming.bonus_percent) && (
              <p className="mt-1 text-xs">
                The price is adjusted for the bonus on the book close (divided by {(1 + (upcoming.bonus_percent ?? 0) / 100).toFixed(2)}). Levels on your watchlist are adjusted automatically.
              </p>
            )}
          </div>
        ) : (
          <p className="text-sm text-slate">No book close announced in the next 45 days.</p>
        )}

        {history.length > 0 && (
          <table className="mt-4 w-full text-sm">
            <thead className="text-left text-xs text-slate">
              <tr>
                <th className="py-1 font-medium">Fiscal year</th>
                <th className="py-1 text-right font-medium">Cash</th>
                <th className="py-1 text-right font-medium">Bonus</th>
                <th className="py-1 text-right font-medium">Book close</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-mist/60">
              {history.map((row) => (
                <tr key={row.fiscal_year}>
                  <td className="py-1.5 text-ink">{row.fiscal_year}</td>
                  <td className="py-1.5 text-right font-mono">{pct(row.cash_percent)}</td>
                  <td className="py-1.5 text-right font-mono">{pct(row.bonus_percent)}</td>
                  <td className="py-1.5 text-right text-slate">{day(row.book_close_on)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </CardBody>
    </Card>
  )
}
