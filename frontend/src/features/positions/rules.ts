// Mirrors Position::MAX_STOP_PCT and Position.default_stop on the server.
export const MAX_STOP_PCT = 8

/** The setup's stop, raised to 8% below entry when it's further away. */
export function defaultStop(entry: number, setupStop: number | null | undefined) {
  const floor = Math.round(entry * (1 - MAX_STOP_PCT / 100) * 100) / 100
  return setupStop && setupStop > 0 ? Math.max(setupStop, floor) : floor
}
