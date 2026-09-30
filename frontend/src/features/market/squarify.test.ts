import { squarify } from "./squarify"

describe("squarify", () => {
  const rect = { x: 0, y: 0, w: 2, h: 1 }

  it("gives each item an area proportional to its value, inside the rect", () => {
    const items = [{ id: "a", v: 6 }, { id: "b", v: 3 }, { id: "c", v: 2 }, { id: "d", v: 1 }]
    const tiles = squarify(items, (item) => item.v, rect)

    expect(tiles.map((tile) => tile.item.id)).toEqual(["a", "b", "c", "d"])
    for (const tile of tiles) {
      expect(tile.w * tile.h).toBeCloseTo((tile.item.v / 12) * 2, 6)
      expect(tile.x).toBeGreaterThanOrEqual(0)
      expect(tile.y).toBeGreaterThanOrEqual(0)
      expect(tile.x + tile.w).toBeLessThanOrEqual(2 + 1e-9)
      expect(tile.y + tile.h).toBeLessThanOrEqual(1 + 1e-9)
    }
  })

  it("keeps equal items close to square", () => {
    const tiles = squarify([1, 1, 1, 1, 1, 1, 1, 1], (v) => v, rect)
    for (const tile of tiles) expect(Math.max(tile.w / tile.h, tile.h / tile.w)).toBeLessThan(2.1)
  })

  it("skips items without a value and handles an empty list", () => {
    expect(squarify([0, -1, 5], (v) => v, rect)).toHaveLength(1)
    expect(squarify([], (v: number) => v, rect)).toEqual([])
  })
})
