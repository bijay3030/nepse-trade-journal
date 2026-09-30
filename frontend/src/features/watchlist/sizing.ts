// Shares to buy so that a stop-out loses `riskPercent` of capital.
export function positionSize(capital: number, riskPercent: number, entry: number, stop: number) {
  if (!(capital > 0 && riskPercent > 0 && entry > stop && stop > 0)) return null
  return Math.floor((capital * (riskPercent / 100)) / (entry - stop))
}
