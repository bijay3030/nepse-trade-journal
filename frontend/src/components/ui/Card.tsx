import type { HTMLAttributes, ReactNode } from "react"
import { cn } from "../../lib/cn"

export function Card({ children, className, ...props }: HTMLAttributes<HTMLElement> & { children: ReactNode }) {
  return (
    <section
      {...props}
      className={cn(
        "rounded-2xl border border-white/70 bg-white/85 p-5 shadow-panel backdrop-blur-sm",
        className,
      )}
    >
      {children}
    </section>
  )
}

export function CardHeader({
  title,
  subtitle,
  className,
}: {
  title: ReactNode
  subtitle?: ReactNode
  className?: string
}) {
  return (
    <header className={cn("mb-4", className)}>
      <h3 className="font-display text-lg font-bold text-ink">{title}</h3>
      {subtitle ? <p className="mt-1 text-sm text-slate/80">{subtitle}</p> : null}
    </header>
  )
}

export function CardBody({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn(className)}>{children}</div>
}
