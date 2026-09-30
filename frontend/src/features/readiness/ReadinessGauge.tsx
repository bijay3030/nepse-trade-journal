import { readinessTone } from "./labels"

// Circular 0-100 gauge.
export function ReadinessGauge({ score, size = 64 }: { score: number; size?: number }) {
  const radius = size / 2 - 5
  const circumference = 2 * Math.PI * radius
  const clamped = Math.max(0, Math.min(100, score))
  const tone = readinessTone(clamped)

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img" aria-label={`Entry readiness ${clamped} of 100`}>
      <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="#e2e8f0" strokeWidth={size / 10} />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke={tone.stroke}
        strokeWidth={size / 10}
        strokeLinecap="round"
        strokeDasharray={`${(clamped / 100) * circumference} ${circumference}`}
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      <text x="50%" y="50%" dominantBaseline="central" textAnchor="middle" fontSize={size / 3.6} fontWeight={700} fill="#1f2d42">
        {clamped}
      </text>
    </svg>
  )
}
