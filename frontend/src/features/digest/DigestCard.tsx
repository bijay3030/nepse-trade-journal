import { format, parseISO } from "date-fns"
import { Newspaper } from "lucide-react"
import { Link } from "react-router-dom"

import { Badge, Card } from "../../components/ui"
import { useDigest } from "./api"

// Dashboard summary of the latest digest, linking to the full page.
export function DigestCard() {
  const { data, isLoading, isError } = useDigest("latest")
  if (isLoading) return null

  if (isError || !data) {
    return (
      <Card className="flex items-center gap-3 p-4 text-sm text-slate">
        <Newspaper className="h-5 w-5 shrink-0" aria-hidden="true" />
        <span>
          No daily digest yet. It's built after each close; turn it on or choose sections in <Link to="/settings" className="font-semibold text-ink underline">Settings</Link>.
        </span>
      </Card>
    )
  }

  const { content } = data
  const facts = [
    content.entry_zone && `${content.entry_zone.count} on Entry zone now (${content.entry_zone.joined.length} new, ${content.entry_zone.left.length} left)`,
    content.watchlist && `${content.watchlist.verdicts.length} watchlist verdicts, ${content.watchlist.alerts.length} alerts`,
    content.watchlist?.book_closes.length ? `${content.watchlist.book_closes.length} book closes within 10 days` : null,
  ].filter(Boolean)

  return (
    <Card className="p-4" aria-label="Daily digest">
      <div className="flex flex-wrap items-center gap-3">
        <Newspaper className="h-5 w-5 shrink-0 text-ink" aria-hidden="true" />
        <div className="min-w-0 flex-1">
          <p className="font-display font-bold text-ink">
            Daily digest · {format(parseISO(data.traded_on), "EEE, MMM d")}
            {!data.read_at && <Badge tone="gain" className="ml-2 align-middle">New</Badge>}
          </p>
          <p className="text-sm text-slate">{data.headline}</p>
          {facts.length > 0 && <p className="text-xs text-slate">{facts.join(" · ")}</p>}
        </div>
        <Link to="/digest" className="rounded-lg bg-ink px-3 py-2 text-sm font-semibold text-white hover:bg-ink/90">
          Open digest
        </Link>
      </div>
    </Card>
  )
}
