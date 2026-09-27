import { useEffect, useRef, useState } from "react"

type Options = {
  threshold?: number
  enabled?: boolean
  onRefresh: () => void
}

export function usePullToRefresh({ onRefresh, threshold = 72, enabled = true }: Options) {
  const startYRef = useRef<number | null>(null)
  const pullingRef = useRef(false)
  const [pullDistance, setPullDistance] = useState(0)
  const [isRefreshing, setIsRefreshing] = useState(false)

  useEffect(() => {
    if (!enabled) return

    const onTouchStart = (event: TouchEvent) => {
      if (window.scrollY > 0) return
      startYRef.current = event.touches[0]?.clientY ?? null
      pullingRef.current = true
    }

    const onTouchMove = (event: TouchEvent) => {
      if (!pullingRef.current || startYRef.current === null) return
      const currentY = event.touches[0]?.clientY ?? startYRef.current
      const distance = Math.max(0, currentY - startYRef.current)
      if (distance > 0 && window.scrollY === 0) {
        setPullDistance(Math.min(120, distance * 0.45))
      }
    }

    const onTouchEnd = async () => {
      if (!pullingRef.current) return
      const shouldRefresh = pullDistance >= threshold
      startYRef.current = null
      pullingRef.current = false
      setPullDistance(0)

      if (shouldRefresh) {
        setIsRefreshing(true)
        await Promise.resolve(onRefresh())
        window.setTimeout(() => setIsRefreshing(false), 500)
      }
    }

    window.addEventListener("touchstart", onTouchStart, { passive: true })
    window.addEventListener("touchmove", onTouchMove, { passive: true })
    window.addEventListener("touchend", onTouchEnd, { passive: true })

    return () => {
      window.removeEventListener("touchstart", onTouchStart)
      window.removeEventListener("touchmove", onTouchMove)
      window.removeEventListener("touchend", onTouchEnd)
    }
  }, [enabled, onRefresh, pullDistance, threshold])

  return { pullDistance, isRefreshing }
}

