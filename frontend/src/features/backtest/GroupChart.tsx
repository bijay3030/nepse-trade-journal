import { Bar, BarChart, CartesianGrid, Legend, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"

import type { GroupStats, Horizon } from "./types"

const MIN_SAMPLE = 30

// Average forward return and excess over NEPSE per group, with sample sizes.
export function GroupChart({ groups, horizon, labels = {} }: { groups: Record<string, GroupStats>; horizon: Horizon; labels?: Record<string, string> }) {
  const rows = Object.entries(groups).map(([key, stats]) => ({
    group: labels[key] ?? key,
    avg: stats[horizon]?.avg_return_pct ?? 0,
    excess: stats[horizon]?.avg_excess_pct ?? 0,
    win: stats[horizon]?.win_rate_pct ?? null,
    n: stats[horizon]?.n ?? 0,
  }))

  return (
    <div>
      <div className="h-56">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={rows} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
            <CartesianGrid strokeDasharray="4 4" stroke="#e2e8f0" vertical={false} />
            <XAxis dataKey="group" fontSize={11} stroke="#64748b" />
            <YAxis fontSize={11} stroke="#64748b" width={44} tickFormatter={(value: number) => `${value}%`} />
            <Tooltip formatter={(value, name) => [`${Number(value).toFixed(2)}%`, name === "avg" ? "Avg return" : "Avg vs NEPSE"]} />
            <Legend formatter={(value) => (value === "avg" ? "Avg return" : "Avg vs NEPSE")} />
            <ReferenceLine y={0} stroke="#94a3b8" />
            <Bar dataKey="avg" fill="#003893" />
            <Bar dataKey="excess" fill="#18745a" />
          </BarChart>
        </ResponsiveContainer>
      </div>
      <table className="mt-2 w-full text-xs">
        <thead className="text-left text-slate">
          <tr>
            <th className="py-1 font-medium">Group</th>
            <th className="py-1 text-right font-medium">Samples</th>
            <th className="py-1 text-right font-medium">Avg return</th>
            <th className="py-1 text-right font-medium">Win rate</th>
            <th className="py-1 text-right font-medium">Vs NEPSE</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-mist/60">
          {rows.map((row) => (
            <tr key={row.group} className={row.n < MIN_SAMPLE ? "text-slate/60" : "text-ink"}>
              <td className="py-1">{row.group}{row.n < MIN_SAMPLE && row.n > 0 && <span className="ml-1 text-amber-700">small sample</span>}</td>
              <td className="py-1 text-right font-mono">{row.n.toLocaleString()}</td>
              <td className="py-1 text-right font-mono">{row.n ? `${row.avg.toFixed(2)}%` : "—"}</td>
              <td className="py-1 text-right font-mono">{row.win === null ? "—" : `${row.win}%`}</td>
              <td className="py-1 text-right font-mono">{row.n ? `${row.excess > 0 ? "+" : ""}${row.excess.toFixed(2)}%` : "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
