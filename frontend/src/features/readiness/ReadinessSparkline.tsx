import type { ReadinessHistoryPoint } from "../screener/types"

const THRESHOLD = 60

/**
 * Readiness over recent sessions with the 60 line dashed and dots on sessions that
 * met the entry-zone criteria. The scale is 0-100, or with `fitRange` the history's
 * own range (padded), so a small sparkline still shows the trend.
 */
export function ReadinessSparkline({
  history,
  width = 240,
  height = 56,
  showDots = true,
  fitRange = false,
  className,
}: {
  history: ReadinessHistoryPoint[]
  width?: number
  height?: number
  showDots?: boolean
  fitRange?: boolean
  className?: string
}) {
  if (history.length < 2) return null

  const pad = 3
  const x = (i: number) => pad + (i / (history.length - 1)) * (width - pad * 2)
  const scores = history.map((point) => point.score)
  const low = fitRange ? Math.max(0, Math.min(...scores) - 5) : 0
  const high = fitRange ? Math.min(100, Math.max(...scores) + 5) : 100
  const y = (score: number) => pad + (1 - (score - low) / (high - low || 1)) * (height - pad * 2)
  const points = history.map((point, i) => `${x(i).toFixed(1)},${y(point.score).toFixed(1)}`).join(" ")
  const first = history[0]
  const last = history[history.length - 1]
  const rising = last.score >= first.score

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      width={width}
      height={height}
      role="img"
      aria-label={`Readiness over ${history.length} sessions: ${first.score} to ${last.score}`}
      className={className}
      preserveAspectRatio="none"
    >
      {THRESHOLD >= low && THRESHOLD <= high && <line x1={pad} x2={width - pad} y1={y(THRESHOLD)} y2={y(THRESHOLD)} stroke="#94a3b8" strokeWidth={1} strokeDasharray="3 3" />}
      <polyline points={points} fill="none" stroke={rising ? "#18745a" : "#b7791f"} strokeWidth={1.75} strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
      {showDots &&
        history.map((point, i) =>
          point.in_buy_zone ? <circle key={point.traded_on} cx={x(i)} cy={y(point.score)} r={2.5} fill="#18745a" data-testid="entry-zone-day" /> : null,
        )}
    </svg>
  )
}
