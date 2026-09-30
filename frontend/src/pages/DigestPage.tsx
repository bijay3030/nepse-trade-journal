import { format, parseISO } from "date-fns"
import { useEffect, useState } from "react"
import { Link } from "react-router-dom"

import { Card, LoadingSpinner, Select } from "../components/ui"
import { useDigest, useDigests, useMarkDigestRead } from "../features/digest/api"
import { DigestView } from "../features/digest/DigestView"

export function DigestPage() {
  const [date, setDate] = useState("latest")
  const list = useDigests()
  const { data, isLoading, isError } = useDigest(date)
  const markRead = useMarkDigestRead()
  const { mutate } = markRead

  // Opening a digest marks it read.
  useEffect(() => {
    if (data && !data.read_at) mutate(data.traded_on)
  }, [data, mutate])

  const digests = list.data?.digests ?? []

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-end gap-3">
        <div className="min-w-0 flex-1">
          <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Daily Digest</h1>
          <p className="mt-1 text-sm text-slate">
            {data ? `After the ${format(parseISO(data.traded_on), "EEEE, MMM d")} close · ${data.headline}` : "An end-of-day summary built after each close."}
          </p>
        </div>
        {digests.length > 1 && (
          <label className="text-sm font-semibold text-slate">
            Session
            <Select className="mt-1" value={date} onChange={(event) => setDate(event.target.value)} aria-label="Digest session">
              <option value="latest">Latest</option>
              {digests.map((digest) => (
                <option key={digest.traded_on} value={digest.traded_on}>
                  {format(parseISO(digest.traded_on), "MMM d")}{digest.read_at ? "" : " (new)"}
                </option>
              ))}
            </Select>
          </label>
        )}
      </header>

      {isLoading ? (
        <div className="flex justify-center py-16"><LoadingSpinner /></div>
      ) : isError || !data ? (
        <Card className="p-8 text-center">
          <p className="font-display text-lg font-bold text-ink">No digest yet</p>
          <p className="mt-2 text-sm text-slate">
            Digests are built after the nightly snapshots (4:45 PM Nepal time, Mon-Fri). If you turned the digest off, switch it back on in{" "}
            <Link to="/settings" className="font-semibold text-ink underline">Settings</Link>.
          </p>
        </Card>
      ) : Object.keys(data.content).some((key) => ["market", "entry_zone", "watchlist"].includes(key)) ? (
        <DigestView content={data.content} />
      ) : (
        <Card className="p-8 text-center text-sm text-slate">All digest sections are switched off in Settings.</Card>
      )}
    </div>
  )
}
