import { useEffect, useState } from "react"
import { useStockPricesStore } from "../../stores/stockPricesStore"

type PriceDisplayProps = {
  amount: number | null | undefined
  showSign?: boolean
  size?: "sm" | "md" | "lg"
  symbol?: string
  showArrow?: boolean
}

export function PriceDisplay({ amount, showSign = false, size = "md", symbol, showArrow = false }: PriceDisplayProps) {
  const live = useStockPricesStore((state) => (symbol ? state.prices[symbol.toUpperCase()] : undefined))
  const [flash, setFlash] = useState<"up" | "down" | null>(null)

  useEffect(() => {
    if (!live?.flashDirection) return
    setFlash(live.flashDirection)

    const timeout = window.setTimeout(() => {
      setFlash(null)
    }, 1000)

    return () => window.clearTimeout(timeout)
  }, [live?.flashTs, live?.flashDirection])

  const value = Number(live?.lastPrice ?? amount ?? 0)
  const sign = showSign && value > 0 ? "+" : ""
  const color = value >= 0 ? "text-pine" : "text-ember"
  const sizeClass = size === "lg" ? "text-3xl" : size === "sm" ? "text-sm" : "text-lg"
  const arrow =
    showArrow && live ? (live.changePercent > 0 ? "↑" : live.changePercent < 0 ? "↓" : "→") : null
  const flashClass = flash === "up" ? "bg-pine/15" : flash === "down" ? "bg-ember/15" : "bg-transparent"

  return (
    <span className={`${sizeClass} inline-flex items-center gap-1 rounded px-1 font-display font-bold transition-colors duration-1000 ease-out ${color} ${flashClass}`}>
      {sign}Rs. {value.toLocaleString(undefined, { maximumFractionDigits: 2 })}
      {arrow ? <span className="text-xs">{arrow}</span> : null}
    </span>
  )
}
