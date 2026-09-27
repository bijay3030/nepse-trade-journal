import { Suspense, lazy } from "react"
import { LoadingSpinner } from "../components/ui"

const AnalyticsDashboard = lazy(async () =>
  import("../components/dashboard/AnalyticsDashboard").then((m) => ({ default: m.AnalyticsDashboard })),
)

export function AnalyticsPage() {
  return (
    <Suspense
      fallback={
        <div className="flex h-[50vh] items-center justify-center">
          <LoadingSpinner size="lg" />
        </div>
      }
    >
      <AnalyticsDashboard />
    </Suspense>
  )
}
