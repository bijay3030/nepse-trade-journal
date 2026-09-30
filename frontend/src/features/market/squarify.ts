export type Rect = { x: number; y: number; w: number; h: number }

type Node<T> = { item: T; area: number }

/**
 * Squarified treemap (Bruls, Huizing & van Wijk): lays items out inside `rect`
 * with areas proportional to `value`, keeping tiles close to square. Largest
 * first; items with no value are left out.
 */
export function squarify<T>(items: T[], value: (item: T) => number, rect: Rect): Array<Rect & { item: T }> {
  const total = items.reduce((sum, item) => sum + Math.max(value(item), 0), 0)
  if (total <= 0 || rect.w <= 0 || rect.h <= 0) return []

  const scale = (rect.w * rect.h) / total
  const nodes: Node<T>[] = items
    .map((item) => ({ item, area: Math.max(value(item), 0) * scale }))
    .filter((node) => node.area > 0)
    .sort((a, b) => b.area - a.area)

  const out: Array<Rect & { item: T }> = []
  let { x, y, w, h } = rect
  let row: Node<T>[] = []

  // Worst aspect ratio of a row laid along a side of this length.
  const worst = (candidate: Node<T>[], side: number) => {
    const sum = candidate.reduce((s, node) => s + node.area, 0)
    const max = Math.max(...candidate.map((node) => node.area))
    const min = Math.min(...candidate.map((node) => node.area))
    return Math.max((side * side * max) / (sum * sum), (sum * sum) / (side * side * min))
  }

  const layoutRow = () => {
    const sum = row.reduce((s, node) => s + node.area, 0)
    if (w >= h) {
      // A column on the left.
      const width = sum / h
      let offset = y
      for (const node of row) {
        const height = node.area / width
        out.push({ item: node.item, x, y: offset, w: width, h: height })
        offset += height
      }
      x += width
      w -= width
    } else {
      // A row along the top.
      const height = sum / w
      let offset = x
      for (const node of row) {
        const width = node.area / height
        out.push({ item: node.item, x: offset, y, w: width, h: height })
        offset += width
      }
      y += height
      h -= height
    }
    row = []
  }

  let i = 0
  while (i < nodes.length) {
    const side = Math.min(w, h)
    const next = [...row, nodes[i]]
    if (row.length === 0 || worst(next, side) <= worst(row, side)) {
      row = next
      i += 1
    } else {
      layoutRow()
    }
  }
  if (row.length > 0) layoutRow()
  return out
}
