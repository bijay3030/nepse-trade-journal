import { useEffect, useState } from "react"
import { Copy, Send } from "lucide-react"

import { Button, Card, CardBody, CardHeader } from "../../components/ui"
import { apiErrorMessage } from "../watchlist/api"
import { type TelegramLink, useTelegramCheck, useTelegramLink, useTelegramStatus, useTelegramTest, useTelegramUnlink, useUpdateTelegram } from "./api"

const CHECK_EVERY_MS = 4000

function Switch({ label, help, checked, disabled, onChange }: { label: string; help: string; checked: boolean; disabled?: boolean; onChange: (on: boolean) => void }) {
  return (
    <label className="flex items-start justify-between gap-3 rounded-xl border border-mist/70 bg-white/90 px-4 py-3">
      <span>
        <span className="block text-sm font-semibold text-ink">{label}</span>
        <span className="block text-xs text-slate">{help}</span>
      </span>
      <input type="checkbox" checked={checked} disabled={disabled} onChange={(event) => onChange(event.target.checked)} className="mt-1 h-4 w-4 accent-ink" />
    </label>
  )
}

function ConnectSteps({ link, checking, onCheck }: { link: TelegramLink; checking: boolean; onCheck: () => void }) {
  const [copied, setCopied] = useState(false)
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(link.code)
      setCopied(true)
    } catch {
      setCopied(false)
    }
  }

  return (
    <div className="space-y-3 text-sm text-slate">
      <ol className="list-decimal space-y-1 pl-5">
        <li>
          In Telegram (phone or computer), open <b className="text-ink">@{link.bot_username}</b>: search for it, or{" "}
          <a href={link.link_url} target="_blank" rel="noreferrer" className="font-semibold text-ink underline">open it from here</a>.
        </li>
        <li>Send the bot this code as a message:</li>
      </ol>
      <div className="flex flex-wrap items-center gap-3 pl-5">
        <code aria-label="Connection code" className="rounded-lg bg-slate/10 px-3 py-2 font-mono text-xl font-bold tracking-[0.25em] text-ink">
          {link.code}
        </code>
        <Button variant="outline" size="sm" onClick={() => void copy()}>
          <Copy className="mr-1 inline h-3.5 w-3.5" aria-hidden="true" />
          {copied ? "Copied" : "Copy code"}
        </Button>
      </div>
      <p className="pl-5">This page connects within a few seconds of the bot getting the code. The code works once and expires in 30 minutes.</p>
      <Button variant="outline" size="sm" disabled={checking} onClick={onCheck}>I've sent the code</Button>
    </div>
  )
}

// Connect a Telegram chat for entry-zone messages. Saved to the account.
export function TelegramSettingsCard() {
  const { data, isLoading, isError } = useTelegramStatus()
  const link = useTelegramLink()
  const check = useTelegramCheck()
  const unlink = useTelegramUnlink()
  const test = useTelegramTest()
  const update = useUpdateTelegram()
  const { mutate: checkNow } = check

  // While a connect link is open, look for the Start message every few seconds.
  const waiting = Boolean(data?.pending && !data.linked && link.data)
  useEffect(() => {
    if (!waiting) return
    const timer = window.setInterval(() => checkNow(), CHECK_EVERY_MS)
    return () => window.clearInterval(timer)
  }, [waiting, checkNow])

  const error = [link, check, unlink, test, update].find((mutation) => mutation.isError)?.error

  return (
    <Card>
      <CardHeader title="Telegram" subtitle="Entry-zone messages in your Telegram chat. Saved to your account." />
      <CardBody className="space-y-3">
        {isLoading ? (
          <p className="text-sm text-slate">Loading…</p>
        ) : isError || !data ? (
          <p className="text-sm text-ember">Couldn't load your Telegram settings.</p>
        ) : !data.configured ? (
          <p className="text-sm text-slate">
            Telegram isn't set up on the server yet. Create a bot with @BotFather, set <code className="rounded bg-slate/10 px-1">TELEGRAM_BOT_TOKEN</code> for the
            Rails server and restart it.
          </p>
        ) : data.linked ? (
          <>
            <div className="flex flex-wrap items-center gap-3">
              <p className="flex-1 text-sm text-ink">
                <Send className="mr-1 inline h-4 w-4 text-pine" aria-hidden="true" />
                Connected{data.username ? ` as @${data.username}` : ""}.
                {test.data?.sent && <span className="ml-2 text-pine">Test message sent.</span>}
              </p>
              <Button variant="outline" size="sm" disabled={test.isPending} onClick={() => test.mutate()}>Send test message</Button>
              <Button variant="ghost" size="sm" disabled={unlink.isPending} onClick={() => unlink.mutate()}>Disconnect</Button>
            </div>
            <div className="grid gap-3 md:grid-cols-2">
              <Switch
                label="Watchlist stock enters its zone"
                help="During market hours, within about 5 minutes. Once per stock per day."
                checked={data.watchlist_alerts}
                disabled={update.isPending}
                onChange={(on) => update.mutate({ watchlist_alerts: on })}
              />
              <Switch
                label="New on Entry zone now"
                help="After the close (about 4:45 PM Nepal time): stocks that newly met every entry-zone rule."
                checked={data.board_alerts}
                disabled={update.isPending}
                onChange={(on) => update.mutate({ board_alerts: on })}
              />
            </div>
          </>
        ) : link.data ? (
          <ConnectSteps link={link.data} checking={check.isPending} onCheck={() => checkNow()} />
        ) : (
          <div className="flex flex-wrap items-center gap-3">
            <p className="flex-1 text-sm text-slate">Get a message when a tracked stock enters its zone, and a list of stocks new on Entry zone now after each close.</p>
            <Button disabled={link.isPending} onClick={() => link.mutate()}>Connect Telegram</Button>
          </div>
        )}
        {error ? <p className="text-sm text-ember">{apiErrorMessage(error)}</p> : null}
        <p className="text-xs text-slate">Rule checks, not recommendations. Send /stop to the bot to disconnect from Telegram.</p>
      </CardBody>
    </Card>
  )
}
