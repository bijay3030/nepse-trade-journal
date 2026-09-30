import { format, parseISO } from "date-fns"
import { Bar, BarChart, CartesianGrid, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import { Badge, Card, CardBody, CardHeader } from "../../components/ui"
import { FLOW_LABELS, FLOW_TONE } from "../readiness/labels"
import type { BrokerFlow, FlowBroker } from "../screener/types"

const qty = (value: number) => value.toLocaleString("en-US")
const price = (value: number | null) => (value === null ? "—" : value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }))
const signed = (value: number) => `${value > 0 ? "+" : ""}${value.toFixed(2)}`

function BrokerTable({ title, brokers, side }: { title: string; brokers: FlowBroker[]; side: "buy" | "sell" }) {
  return (
    <div>
      <h4 className="text-xs font-bold uppercase tracking-wide text-slate">{title}</h4>
      {brokers.length === 0 ? (
        <p className="mt-2 text-sm text-slate">None in this window.</p>
      ) : (
        <div className="mt-2 overflow-x-auto">
        <table className="w-full min-w-[26rem] text-sm">
          <thead className="text-left text-xs text-slate">
            <tr>
              <th className="py-1 font-medium">Broker</th>
              <th className="py-1 text-right font-medium">Net shares</th>
              <th className="py-1 text-right font-medium">% of volume</th>
              <th className="py-1 text-right font-medium">{side === "buy" ? "Avg price paid" : "Avg price received"}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-mist/60">
            {brokers.map((broker) => (
              <tr key={broker.broker_no}>
                <td className="py-1.5">
                  <span className="font-semibold text-ink">#{broker.broker_no}</span>
                  {broker.name && <span className="block truncate text-xs text-slate">{broker.name}</span>}
                </td>
                <td className={`py-1.5 text-right font-mono ${side === "buy" ? "text-pine" : "text-ember"}`}>{qty(broker.net_quantity)}</td>
                <td className="py-1.5 text-right font-mono">{broker.share_pct.toFixed(1)}%</td>
                <td className="py-1.5 text-right font-mono">{price(side === "buy" ? broker.avg_buy_price : broker.avg_sell_price)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      )}
    </div>
  )
}

// Who has been accumulating or distributing, from the daily floorsheet.
export function BrokerFlowCard({ flow }: { flow: BrokerFlow }) {
  if (flow.state === "no_data") {
    return (
      <Card>
        <CardHeader title="Broker flow" subtitle="From the NEPSE floorsheet" />
        <CardBody>
          <p className="text-sm text-slate">
            Not enough floorsheet data yet ({flow.sessions} of 5 sessions). Run <code>bin/rails nepse:data:floorsheet</code> to load it.
          </p>
        </CardBody>
      </Card>
    )
  }

  const long = flow.windows["20"]
  const short = flow.windows["5"]
  return (
    <Card>
      <CardHeader title="Broker flow" subtitle={`Net buying by the top 5 brokers vs net selling by the top 5, over ${long?.sessions ?? flow.sessions} sessions`} />
      <CardBody>
        <div className="flex flex-wrap items-center gap-3">
          <Badge tone={FLOW_TONE[flow.state]}>{FLOW_LABELS[flow.state]}</Badge>
          <span className="text-sm text-slate">
            Flow score <b className="font-mono text-ink">{flow.score === null ? "—" : signed(flow.score)}</b> points
          </span>
        </div>
        {flow.thin_trading && (
          <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
            Thin trading: under NPR 20M changed hands in 20 sessions, so a single client can move these numbers. Shown as neutral.
          </p>
        )}
        <dl className="mt-3 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          {[
            ["Top buyers, 20 sessions", long?.top_buyers_pct],
            ["Top sellers, 20 sessions", long?.top_sellers_pct],
            ["Top buyers, 5 sessions", short?.top_buyers_pct],
            ["Top sellers, 5 sessions", short?.top_sellers_pct],
          ].map(([label, value]) => (
            <div key={label as string} className="rounded-lg bg-slate/5 px-3 py-2">
              <dt className="text-xs text-slate">{label}</dt>
              <dd className="font-mono font-semibold text-ink">{value === undefined ? "—" : `${(value as number).toFixed(1)}% of volume`}</dd>
            </div>
          ))}
        </dl>

        <div className="mt-4 h-52" aria-label="Daily net shares of the top buyers and top sellers">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={flow.daily} margin={{ top: 4, right: 8, bottom: 0, left: 0 }}>
              <CartesianGrid strokeDasharray="4 4" stroke="#e2e8f0" vertical={false} />
              <XAxis dataKey="traded_on" tickFormatter={(value: string) => format(parseISO(value), "MMM d")} fontSize={11} stroke="#64748b" />
              <YAxis fontSize={11} stroke="#64748b" width={56} tickFormatter={(value: number) => value.toLocaleString("en-US", { notation: "compact" })} />
              <Tooltip
                labelFormatter={(value) => format(parseISO(String(value)), "MMM d, yyyy")}
                formatter={(value, name) => [qty(Number(value)), name === "top_buyers_net" ? "Top buyers, net" : "Top sellers, net"]}
              />
              <ReferenceLine y={0} stroke="#94a3b8" />
              <Bar dataKey="top_buyers_net" fill="#18745a" name="top_buyers_net" />
              <Bar dataKey="top_sellers_net" fill="#d64545" name="top_sellers_net" />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <p className="mt-1 text-xs text-slate">Green: net shares of the window's top 5 buyers each day. Red: the top 5 sellers.</p>

        <div className="mt-5 grid gap-6 2xl:grid-cols-2">
          <BrokerTable title="Top net buyers" brokers={flow.top_buyers} side="buy" />
          <BrokerTable title="Top net sellers" brokers={flow.top_sellers} side="sell" />
        </div>
        <p className="mt-3 text-[11px] text-slate">
          Concentrated net buying can mean accumulation, but brokers trade for many clients; treat it as one input, not a signal on its own.
        </p>
      </CardBody>
    </Card>
  )
}
