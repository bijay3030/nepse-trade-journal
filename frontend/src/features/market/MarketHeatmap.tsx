import { format } from "date-fns"
import { useEffect, useMemo, useState } from "react"
import { Link } from "react-router-dom"

import { Button, Card, CardBody, CardHeader, LoadingSpinner } from "../../components/ui"
import { useIsMobile } from "../../hooks/useIsMobile"
import { useMarketHeatmap } from "./api"
import { CHANGE_BANDS, changeBand } from "./colors"
import { squarify } from "./squarify"
import type { HeatmapSector, HeatmapStock } from "./types"

const pct = (value: number) => `${value > 0 ? "+" : ""}${value.toFixed(2)}%`
const HEADER_PX = 18

// Width of an element, following resizes; a fallback where ResizeObserver is missing (tests).
// A callback ref, because the map mounts after the loading state.
function useWidth(fallback: number) {
  const [element, setElement] = useState<HTMLDivElement | null>(null)
  const [width, setWidth] = useState(fallback)
  useEffect(() => {
    if (!element || typeof ResizeObserver === "undefined") return
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(element)
    return () => observer.disconnect()
  }, [element])
  return [setElement, width] as const
}

type Tile = { stock: HeatmapStock; x: number; y: number; w: number; h: number }
type SectorBox = { sector: HeatmapSector; x: number; y: number; w: number; h: number; header: boolean; tiles: Tile[] }

// Sectors sized by market cap, then each sector's stocks inside it, in pixels.
function layout(sectors: HeatmapSector[], width: number, height: number): SectorBox[] {
  return squarify(sectors, (sector) => sector.market_cap, { x: 0, y: 0, w: width, h: height }).map((box) => {
    const header = box.h > HEADER_PX * 3 && box.w > 70
    const inner = { x: box.x, y: box.y + (header ? HEADER_PX : 0), w: box.w, h: box.h - (header ? HEADER_PX : 0) }
    const tiles = squarify(box.item.stocks, (stock) => stock.market_cap, inner).map(({ item, ...rect }) => ({ stock: item, ...rect }))
    return { sector: box.item, x: box.x, y: box.y, w: box.w, h: box.h, header, tiles }
  })
}

export function MarketHeatmap() {
  const { data, isLoading, isError, refetch } = useMarketHeatmap()
  const isMobile = useIsMobile()
  const [ref, width] = useWidth(1000)
  const aspect = isMobile ? 0.8 : 2
  const height = width / aspect
  const boxes = useMemo(() => (data ? layout(data.sectors, width, height) : []), [data, width, height])

  const position = (rect: { x: number; y: number; w: number; h: number }) => ({
    left: `${(rect.x / width) * 100}%`,
    top: `${(rect.y / height) * 100}%`,
    width: `${(rect.w / width) * 100}%`,
    height: `${(rect.h / height) * 100}%`,
  })

  return (
    <Card>
      <CardHeader
        title="Market Heatmap"
        subtitle={
          data?.as_of
            ? `Tile size: market cap · colour: day change · prices as of ${format(new Date(data.as_of), "MMM d, h:mm a")}`
            : "Tile size: market cap · colour: day change"
        }
      />
      <CardBody>
        {isLoading ? (
          <div className="flex justify-center py-12"><LoadingSpinner /></div>
        ) : isError || !data ? (
          <div className="py-8 text-center">
            <p className="text-sm text-ember">Couldn't load the heatmap.</p>
            <Button className="mt-3" variant="outline" onClick={() => void refetch()}>Retry</Button>
          </div>
        ) : data.sectors.length === 0 ? (
          <p className="py-8 text-center text-sm text-slate">No stock prices with market cap yet. Sync prices and reference data first.</p>
        ) : (
          <>
            <div ref={ref} className="relative w-full overflow-hidden rounded-lg bg-white" style={{ aspectRatio: String(aspect) }}>
              {boxes.map((box) => (
                <section key={box.sector.sector} aria-label={`${box.sector.sector} ${pct(box.sector.change_percent)}`}>
                  {box.header && (
                    <div
                      className="absolute z-10 flex items-center justify-between gap-1 overflow-hidden whitespace-nowrap bg-ink/85 px-1.5 text-[10px] font-bold uppercase tracking-wide text-white"
                      style={{ ...position({ ...box, h: HEADER_PX }) }}
                    >
                      <span className="truncate">{box.sector.sector}</span>
                      <span>{pct(box.sector.change_percent)}</span>
                    </div>
                  )}
                  {box.tiles.map((tile) => {
                    const band = changeBand(tile.stock.change_percent)
                    const fontSize = Math.min(22, Math.max(10, Math.sqrt(tile.w * tile.h) / 5))
                    // Only whole symbols: a clipped "UPP…" is noise on a small tile.
                    const showSymbol = tile.h > fontSize + 4 && tile.w > tile.stock.symbol.length * fontSize * 0.74 + 8
                    const showChange = showSymbol && tile.w > 44 && tile.h > fontSize + 18
                    return (
                      <Link
                        key={tile.stock.symbol}
                        to={`/screener/${encodeURIComponent(tile.stock.symbol)}`}
                        aria-label={`${tile.stock.symbol} ${pct(tile.stock.change_percent)}`}
                        className="absolute flex flex-col items-center justify-center overflow-hidden border border-white text-center leading-tight transition-[filter] hover:brightness-110 focus-visible:z-20 focus-visible:outline focus-visible:outline-2 focus-visible:outline-ink"
                        style={{ ...position(tile), backgroundColor: band.bg, color: band.text }}
                      >
                        {showSymbol && (
                          <span className="max-w-full truncate px-0.5 font-bold" style={{ fontSize }}>
                            {tile.stock.symbol}
                          </span>
                        )}
                        {showChange && <span className="text-[10px] opacity-90">{pct(tile.stock.change_percent)}</span>}
                      </Link>
                    )
                  })}
                </section>
              ))}
              {boxes.map((box) => (
                <div key={`${box.sector.sector}-outline`} aria-hidden="true" className="pointer-events-none absolute z-10 border-2 border-white" style={position(box)} />
              ))}
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1.5 text-xs text-slate">
              {CHANGE_BANDS.map((band) => (
                <span key={band.label} className="inline-flex items-center gap-1">
                  <span className="h-3 w-3 rounded-sm" style={{ backgroundColor: band.bg }} aria-hidden="true" />
                  {band.label}
                </span>
              ))}
              <span className="ml-auto">
                {data.stocks} stocks{data.unsized > 0 ? ` · ${data.unsized} without market cap not shown` : ""}
              </span>
            </div>
          </>
        )}
      </CardBody>
    </Card>
  )
}
