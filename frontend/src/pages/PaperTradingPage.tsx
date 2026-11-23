import { format, parseISO } from "date-fns"
import { NotebookPen } from "lucide-react"
import { useState, type ReactNode } from "react"
import { Link } from "react-router-dom"

import { Button, Card, LoadingSpinner } from "../components/ui"
import { usePaperAccount, useTogglePaperTrading } from "../features/paper/api"
import type { PaperLogEntry, PaperTradeRow } from "../features/paper/types"
import { cn } from "../lib/cn"

const money = (v: number | null | undefined) => (v == null ? "—" : v.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }))
const rupees = (v: number | null | undefined) => (v == null ? "—" : `${v < 0 ? "-" : "+"}Rs ${money(Math.abs(v))}`)
const pct = (v: number | null | undefined) => (v == null ? "—" : `${v > 0 ? "+" : ""}${v.toFixed(2)}%`)
const tone = (v: number | null | undefined) => (v == null ? "text-slate" : v > 0 ? "text-pine" : v < 0 ? "text-ember" : "text-slate")
const when = (iso: string | null | undefined) => (iso ? format(parseISO(iso), "d MMM, HH:mm") : "—")
const day = (iso: string | null | undefined) => (iso ? format(parseISO(iso), "EEE d MMM") : "—")

const TRIGGERS: Record<PaperTradeRow["trigger"], string> = {
  watchlist_entered_zone: "Watchlist: entered zone", watchlist_breakout: "Watchlist: breakout on volume", board_new: "New on Entry zone",
}
const EXIT_RULES: Record<string, string> = {
  stop_hit: "Stop hit", target_reached: "Target reached", fifty_day_break: "50-day break on volume", climax_run: "Climax run", time_stop: "Time stop",
}
const ACTIONS: Record<PaperLogEntry["action"], { label: string; chip: string }> = {
  signal: { label: "Signal", chip: "bg-slate/10 text-slate" },
  buy: { label: "Buy", chip: "bg-pine/15 text-pine" },
  sell: { label: "Sell", chip: "bg-ember/15 text-ember" },
  hold: { label: "Hold", chip: "bg-amber-100 text-amber-800" },
  skip: { label: "Skipped", chip: "bg-slate/10 text-slate" },
}

export function PaperTradingPage() {
  const { data, isLoading, isError, refetch } = usePaperAccount()
  const toggle = useTogglePaperTrading()

  if (isLoading) return <div className="flex h-[40vh] items-center justify-center"><LoadingSpinner size="lg" /></div>
  if (isError || !data) {
    return (
      <Card className="p-8 text-center">
        <p className="font-display text-lg font-bold text-ink">Couldn't load paper trading</p>
        <Button className="mt-4" variant="outline" onClick={() => void refetch()}>Retry</Button>
      </Card>
    )
  }
  const open = data.trades.filter((t) => t.status === "open")
  const pending = data.trades.filter((t) => t.status === "pending")
  const closed = data.trades.filter((t) => t.status === "closed")
  const s = data.summary

  return (
    <div className="space-y-5">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="flex items-center gap-2 font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl"><NotebookPen className="h-6 w-6" /> Paper Trading</h1>
          <p className="mt-1 max-w-3xl text-sm text-slate">
            Fully automated and simulated: no real order is placed. It buys {data.quantity} shares when a watchlist stock enters its zone or breaks out on volume
            (at the live price) or when a stock is new on Entry zone now (at the next session's first live price), with {data.slippage_pct}% slippage. It sells all of
            them by the app's sell rules once the shares settle (T+2): the stop or target, or at the close on a 50-day break, a climax run or the time stop. NEPSE costs
            and capital gains tax are included. Every step is logged below and sent on Telegram.
          </p>
        </div>
        <label className="flex items-center gap-2 rounded-xl border border-mist/80 bg-white px-3 py-2 text-sm">
          <input type="checkbox" checked={data.enabled} disabled={toggle.isPending} onChange={(e) => toggle.mutate(e.target.checked)} />
          <span className="font-semibold text-ink">Automated paper trading {data.enabled ? "on" : "off"}</span>
        </label>
      </header>

      <dl className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-6" aria-label="Paper account">
        <Box label="Open positions" value={String(s.open)} note={s.pending ? `${s.pending} waiting to buy` : undefined} />
        <Box label="Invested" value={`Rs ${money(s.invested)}`} />
        <Box label="Open P&L (after costs)" value={rupees(s.open_pnl)} valueTone={tone(s.open_pnl)} />
        <Box label="Realised P&L" value={rupees(s.realized_pnl)} valueTone={tone(s.realized_pnl)} note={`${s.closed} closed trades`} />
        <Box label="Won" value={s.win_rate_pct == null ? "—" : `${s.win_rate_pct}%`} />
        <Box label="Profit factor" value={s.profit_factor == null ? "—" : String(s.profit_factor)} note="money won ÷ money lost" />
      </dl>

      <Section title={`Open positions (${open.length})`} empty="No open paper positions.">
        {open.length > 0 && (
          <Table label="Open paper positions" head={["Stock", "Why bought", "Bought", "Price", "Now", "P&L after costs", "Stop / target", "Can sell from"]}>
            {open.map((t) => (
              <tr key={t.id}>
                <td className="px-3 py-2"><StockLink symbol={t.symbol} /></td>
                <td className="max-w-xs px-3 py-2 text-xs text-slate"><b className="text-ink">{TRIGGERS[t.trigger]}</b><span className="block">{t.buy_reason}</span></td>
                <td className="px-3 py-2 text-xs">{when(t.entry_at)}</td>
                <td className="px-3 py-2 text-right font-mono">{money(t.entry_price)}</td>
                <td className="px-3 py-2 text-right font-mono">{money(t.last_price)}</td>
                <td className={cn("px-3 py-2 text-right font-mono font-semibold", tone(t.unrealized_pnl))}>{rupees(t.unrealized_pnl)}</td>
                <td className="px-3 py-2 text-right font-mono text-xs"><span className="text-ember">{money(t.stop_price)}</span> / <span className="text-pine">{money(t.target_price)}</span></td>
                <td className="px-3 py-2 text-xs">{day(t.sellable_on)}</td>
              </tr>
            ))}
          </Table>
        )}
        {pending.length > 0 && (
          <p className="mt-2 text-xs text-slate" aria-label="Waiting to buy">
            <b className="text-ink">Waiting to buy at the next session's open:</b> {pending.map((t) => `${t.symbol} (${TRIGGERS[t.trigger]}, ${day(t.signal_on)})`).join(", ")}
          </p>
        )}
      </Section>

      <Section title={`Closed trades (${closed.length})`} empty="No closed paper trades yet.">
        {closed.length > 0 && (
          <Table label="Closed paper trades" head={["Stock", "Bought", "Price", "Sold", "Price", "Held", "Why sold", "Net P&L", "Return"]}>
            {closed.map((t) => (
              <tr key={t.id}>
                <td className="px-3 py-2"><StockLink symbol={t.symbol} /><span className="block text-[11px] text-slate">{TRIGGERS[t.trigger]}</span></td>
                <td className="px-3 py-2 text-xs">{when(t.entry_at)}</td>
                <td className="px-3 py-2 text-right font-mono">{money(t.entry_price)}</td>
                <td className="px-3 py-2 text-xs">{when(t.exit_at)}</td>
                <td className="px-3 py-2 text-right font-mono">{money(t.exit_price)}</td>
                <td className="px-3 py-2 text-right text-xs">{t.held_days} {t.held_days === 1 ? "day" : "days"}</td>
                <td className="max-w-xs px-3 py-2 text-xs"><b>{EXIT_RULES[t.exit_rule ?? ""] ?? t.exit_rule}</b><span className="block text-slate">{t.sell_reason}</span></td>
                <td className={cn("px-3 py-2 text-right font-mono font-semibold", tone(t.net_pnl))}>{rupees(t.net_pnl)}{t.cgt ? <span className="block text-[11px] font-normal text-slate">tax Rs {money(t.cgt)}</span> : null}</td>
                <td className={cn("px-3 py-2 text-right font-mono", tone(t.return_pct))}>{pct(t.return_pct)}</td>
              </tr>
            ))}
          </Table>
        )}
      </Section>

      <Log entries={data.log} />
    </div>
  )
}

function Box({ label, value, note, valueTone = "text-ink" }: { label: string; value: string; note?: string; valueTone?: string }) {
  return (
    <div className="rounded-xl border border-mist/80 bg-white px-3 py-2">
      <dt className="text-[11px] font-semibold text-slate">{label}</dt>
      <dd className={cn("font-mono text-lg font-semibold", valueTone)}>{value}</dd>
      {note && <dd className="text-[11px] text-slate">{note}</dd>}
    </div>
  )
}

function Section({ title, empty, children }: { title: string; empty: string; children: ReactNode }) {
  const hasContent = Array.isArray(children) ? children.some(Boolean) : Boolean(children)
  return (
    <section className="space-y-2">
      <h2 className="font-display text-lg font-bold text-ink">{title}</h2>
      {hasContent ? children : <Card className="p-5 text-sm text-slate">{empty}</Card>}
    </section>
  )
}

function Table({ label, head, children }: { label: string; head: string[]; children: ReactNode }) {
  return (
    <Card className="overflow-x-auto">
      <table className="w-full text-sm" aria-label={label}>
        <thead className="border-b border-mist/80 bg-slate/5 text-left text-[11px] font-bold uppercase tracking-wider text-slate">
          <tr>{head.map((h, i) => <th key={`${h}-${i}`} className="px-3 py-2">{h}</th>)}</tr>
        </thead>
        <tbody className="divide-y divide-mist/60">{children}</tbody>
      </table>
    </Card>
  )
}

function StockLink({ symbol }: { symbol: string }) {
  return <Link className="font-bold text-ink hover:underline" to={`/screener/${encodeURIComponent(symbol)}`}>{symbol}</Link>
}

function Log({ entries }: { entries: PaperLogEntry[] }) {
  const [show, setShow] = useState<PaperLogEntry["action"] | "all">("all")
  const shown = entries.filter((e) => show === "all" || e.action === show)
  return (
    <section className="space-y-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="font-display text-lg font-bold text-ink">Log</h2>
        <div className="flex flex-wrap gap-1" role="group" aria-label="Log filter">
          {(["all", "buy", "sell", "hold", "signal", "skip"] as const).map((a) => (
            <button key={a} type="button" onClick={() => setShow(a)} aria-pressed={show === a}
              className={cn("rounded-full border px-2.5 py-0.5 text-xs font-semibold", show === a ? "border-ink bg-ink text-white" : "border-slate/20 text-ink hover:bg-slate/5")}>
              {a === "all" ? "All" : ACTIONS[a].label}
            </button>
          ))}
        </div>
      </div>
      {shown.length === 0 ? <Card className="p-5 text-sm text-slate">Nothing logged yet. The first entries appear when a watchlist stock enters its zone or a stock is new on Entry zone now.</Card> : (
        <Card className="divide-y divide-mist/60" aria-label="Paper trading log">
          {shown.map((e) => (
            <div key={e.id} className="flex gap-3 px-4 py-2.5 text-sm">
              <span className="w-28 shrink-0 text-xs text-slate">{when(e.at)}</span>
              <span className={cn("h-fit shrink-0 rounded-full px-2 py-0.5 text-xs font-bold", ACTIONS[e.action].chip)}>{ACTIONS[e.action].label}</span>
              <span className="w-16 shrink-0"><StockLink symbol={e.symbol} /></span>
              <span className="min-w-0 flex-1 text-ink">{e.reason}</span>
            </div>
          ))}
        </Card>
      )}
    </section>
  )
}
