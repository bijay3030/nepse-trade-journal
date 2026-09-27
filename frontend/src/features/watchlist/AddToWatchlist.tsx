import { BookmarkCheck, BookmarkPlus, X } from "lucide-react"
import { useEffect, useState } from "react"
import { Link } from "react-router-dom"

import { Button, Textarea } from "../../components/ui"
import { cn } from "../../lib/cn"
import { apiErrorMessage, useAddToWatchlist, useSuggestion, useWatchlist } from "./api"
import { SETUP_HELP, SETUP_LABELS, formatPrice } from "./labels"
import { LevelFields } from "./LevelFields"
import { EMPTY_LEVELS, draftToLevels, levelsToDraft, type LevelDraft } from "./levels"
import type { SetupType } from "./types"

export function AddToWatchlistDialog({ symbol, onClose }: { symbol: string; onClose: () => void }) {
  const [setupType, setSetupType] = useState<SetupType>("vcp")
  const [notes, setNotes] = useState("")
  const suggestion = useSuggestion(symbol, setupType, true)
  const add = useAddToWatchlist()

  // Start from the suggestion for the chosen setup; the user's edits replace it
  // until they switch setup type or a new suggestion arrives.
  const suggestionKey = `${setupType}:${suggestion.dataUpdatedAt}`
  const [edited, setEdited] = useState<{
    key: string
    levels: LevelDraft
  } | null>(null)
  const levels = edited?.key === suggestionKey ? edited.levels : suggestion.data?.success ? levelsToDraft(suggestion.data.levels) : EMPTY_LEVELS
  const setLevels = (next: LevelDraft) => setEdited({ key: suggestionKey, levels: next })

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => event.key === "Escape" && onClose()
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose])

  const snapshot = suggestion.data?.success ? suggestion.data.snapshot : null
  const submit = () => {
    const values = draftToLevels(levels)
    add.mutate({
      symbol,
      setup_type: setupType,
      notes: notes.trim() || undefined,
      ...values,
    })
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-0 sm:items-center sm:p-4" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="add-watchlist-title"
        className="max-h-[92vh] w-full max-w-2xl overflow-y-auto rounded-t-2xl bg-white p-5 shadow-xl sm:rounded-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 id="add-watchlist-title" className="font-display text-lg font-bold text-ink">
              Track {symbol}
            </h2>
            <p className="text-sm text-slate">Pick a setup, check the suggested levels, then add it to your watchlist.</p>
          </div>
          <button type="button" aria-label="Close" onClick={onClose} className="rounded-lg p-2 text-slate hover:bg-slate/10">
            <X className="h-4 w-4" />
          </button>
        </div>

        {add.isSuccess ? (
          <div className="mt-5 rounded-xl border border-pine/30 bg-pine/10 p-4 text-sm text-ink">
            <p className="font-semibold">{symbol} is on your watchlist.</p>
            <p className="mt-1 text-slate">You'll get an alert when it enters the zone, runs above it, or hits the invalidation level.</p>
            <div className="mt-3 flex gap-2">
              <Link to="/watchlist" className="rounded-xl bg-ink px-4 py-2 text-sm font-bold text-white">
                Open watchlist
              </Link>
              <Button variant="outline" onClick={onClose}>
                Close
              </Button>
            </div>
          </div>
        ) : (
          <>
            <div className="mt-4 grid grid-cols-2 gap-2" role="radiogroup" aria-label="Setup type">
              {(Object.keys(SETUP_LABELS) as SetupType[]).map((type) => (
                <button
                  key={type}
                  type="button"
                  role="radio"
                  aria-checked={setupType === type}
                  onClick={() => setSetupType(type)}
                  className={cn(
                    "rounded-xl border p-3 text-left text-sm transition",
                    setupType === type ? "border-ink bg-ink/5" : "border-mist hover:bg-slate/5",
                  )}
                >
                  <span className="font-bold text-ink">{SETUP_LABELS[type]}</span>
                  <span className="mt-1 block text-xs text-slate">{SETUP_HELP[type]}</span>
                </button>
              ))}
            </div>

            <div className="mt-4 rounded-xl bg-slate/5 p-3 text-sm" aria-live="polite">
              {suggestion.isLoading ? (
                <p className="text-slate">Analysing {symbol}…</p>
              ) : suggestion.isError ? (
                <p className="text-ember">{apiErrorMessage(suggestion.error)}</p>
              ) : suggestion.data && !suggestion.data.success ? (
                <p className="text-ember">{suggestion.data.error} Enter the levels yourself below.</p>
              ) : snapshot && suggestion.data?.success ? (
                <div className="flex flex-wrap gap-x-5 gap-y-1 text-slate">
                  <span>
                    Price <b className="text-ink">{formatPrice(suggestion.data.current_price)}</b>
                  </span>
                  {setupType === "vcp" && (
                    <span>
                      VCP score <b className="text-ink">{snapshot.vcp_score ?? "—"}</b>
                    </span>
                  )}
                  {setupType === "vcp" && snapshot.contraction_sequence && (
                    <span className="max-w-full truncate">
                      Contractions <b className="text-ink">{snapshot.contraction_sequence}</b>
                    </span>
                  )}
                  <span>
                    Trend <b className="text-ink">{snapshot.trend ?? "—"}</b>
                  </span>
                  <span>
                    Market <b className="text-ink">{snapshot.market_regime ?? "—"}</b>
                  </span>
                  <span>
                    Target from <b className="text-ink">{suggestion.data.levels.target_basis}</b>
                  </span>
                  <span>
                    Data as of <b className="text-ink">{snapshot.analysed_on ?? "—"}</b>
                  </span>
                  {setupType === "vcp" && snapshot.is_vcp_setup === false && (
                    <p className="mt-1 w-full text-amber-800">
                      Not a qualified VCP yet (score {snapshot.vcp_score ?? "—"}; the screener needs 60+ with contracting price and volume). The pivot is still
                      usable as a breakout level.
                    </p>
                  )}
                </div>
              ) : null}
            </div>

            <div className="mt-4">
              <LevelFields idPrefix="add" value={levels} onChange={setLevels} />
            </div>

            <label htmlFor="add-notes" className="mt-4 block text-xs font-semibold text-slate">
              Notes (optional)
              <Textarea
                id="add-notes"
                className="mt-1"
                rows={2}
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                placeholder="Why this setup? What would make you skip it?"
              />
            </label>

            {add.isError && (
              <p role="alert" className="mt-3 text-sm text-ember">
                {apiErrorMessage(add.error)}
              </p>
            )}

            <div className="mt-5 flex justify-end gap-2">
              <Button variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button onClick={submit} disabled={add.isPending || suggestion.isLoading || levels.entry_zone_low === ""}>
                {add.isPending ? "Adding…" : "Add to watchlist"}
              </Button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export function AddToWatchlistButton({ symbol, size = "md" }: { symbol: string; size?: "sm" | "md" }) {
  const [open, setOpen] = useState(false)
  const { data: items } = useWatchlist()
  const existing = items?.find((item) => item.symbol === symbol)

  // Keep the dialog mounted after a successful add so its confirmation stays visible.
  const dialog = open ? <AddToWatchlistDialog symbol={symbol} onClose={() => setOpen(false)} /> : null

  if (existing) {
    return (
      <>
        <Link
          to="/watchlist"
          className={cn(
            "inline-flex items-center gap-1.5 rounded-xl border border-pine/30 bg-pine/10 font-bold text-pine",
            size === "sm" ? "px-2.5 py-1.5 text-xs" : "px-4 py-2.5 text-sm",
          )}
        >
          <BookmarkCheck className="h-4 w-4" /> On watchlist
        </Link>
        {dialog}
      </>
    )
  }

  return (
    <>
      <Button
        variant="outline"
        size={size}
        onClick={() => setOpen(true)}
        className="inline-flex items-center gap-1.5"
        aria-label={`Add ${symbol} to watchlist`}
      >
        <BookmarkPlus className="h-4 w-4" /> {size === "sm" ? "Track" : "Add to watchlist"}
      </Button>
      {dialog}
    </>
  )
}
