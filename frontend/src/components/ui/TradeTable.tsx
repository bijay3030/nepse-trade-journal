import { Badge } from "./Badge"

type TradeRow = {
  symbol: string
  side: "BUY" | "SELL"
  strategy: string
  pnl: string
  mood: string
}

export function TradeTable({ rows }: { rows: TradeRow[] }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-white/70 bg-white/90 shadow-panel">
      <table className="w-full border-collapse text-sm">
        <thead className="bg-ink/95 text-left text-xs uppercase tracking-[0.16em] text-white/75">
          <tr>
            <th className="px-4 py-3">Symbol</th>
            <th className="px-4 py-3">Side</th>
            <th className="px-4 py-3">Strategy</th>
            <th className="px-4 py-3">P/L</th>
            <th className="px-4 py-3">Mood</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={`${row.symbol}-${row.side}-${row.strategy}`} className="border-t border-mist/70">
              <td className="px-4 py-3 font-semibold text-ink">{row.symbol}</td>
              <td className="px-4 py-3">
                <Badge tone={row.side === "BUY" ? "gain" : "loss"}>{row.side}</Badge>
              </td>
              <td className="px-4 py-3 text-slate">{row.strategy}</td>
              <td className="px-4 py-3 font-bold text-ink">{row.pnl}</td>
              <td className="px-4 py-3 text-slate">{row.mood}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
