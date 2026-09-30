// Day-change colour bands, red to green. Light bands use dark text.
export const CHANGE_BANDS = [
  { max: -3, label: "≤ −3%", bg: "#991b1b", text: "#ffffff" },
  { max: -1.5, label: "−3 to −1.5%", bg: "#dc2626", text: "#ffffff" },
  { max: -0.25, label: "−1.5 to 0%", bg: "#f3a1a1", text: "#1f2937" },
  { max: 0.25, label: "Flat", bg: "#cbd5e1", text: "#1f2937" },
  { max: 1.5, label: "0 to 1.5%", bg: "#93d3ae", text: "#1f2937" },
  { max: 3, label: "1.5 to 3%", bg: "#18745a", text: "#ffffff" },
  { max: Infinity, label: "≥ 3%", bg: "#0b4d3a", text: "#ffffff" },
] as const

// Within ±0.25% counts as flat; otherwise the first band whose upper bound is above the change.
export function changeBand(change: number) {
  if (Math.abs(change) <= 0.25) return CHANGE_BANDS[3]
  return CHANGE_BANDS.find((band) => change < band.max) ?? CHANGE_BANDS[CHANGE_BANDS.length - 1]
}
