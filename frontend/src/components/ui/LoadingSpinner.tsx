import { LoaderCircle } from "lucide-react"
import { cn } from "../../lib/cn"

type LoadingSpinnerProps = {
  size?: "sm" | "md" | "lg"
  className?: string
}

export function LoadingSpinner({ size = "md", className }: LoadingSpinnerProps) {
  const sizeClass = size === "lg" ? "h-10 w-10" : size === "sm" ? "h-4 w-4" : "h-6 w-6"
  return <LoaderCircle className={cn("animate-spin text-slate", sizeClass, className)} />
}
