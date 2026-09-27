import "@testing-library/jest-dom/vitest"

// jsdom does not implement ResizeObserver, which Recharts' ResponsiveContainer
// requires. Provide a no-op stub for component tests that render charts.
class ResizeObserverStub {
  observe() {}
  unobserve() {}
  disconnect() {}
}

if (typeof globalThis.ResizeObserver === "undefined") {
  globalThis.ResizeObserver = ResizeObserverStub as unknown as typeof ResizeObserver
}
