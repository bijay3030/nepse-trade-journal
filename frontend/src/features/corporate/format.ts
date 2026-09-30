import { format, parseISO } from "date-fns"

import type { BookClose } from "./types"

export function bookCloseText(bookClose: BookClose) {
  const parts = [
    bookClose.bonus_percent ? `${bookClose.bonus_percent}% bonus` : null,
    bookClose.cash_percent ? `${bookClose.cash_percent}% cash` : null,
  ].filter(Boolean)
  return `Book close ${format(parseISO(bookClose.book_close_on), "MMM d")}${parts.length ? ` · ${parts.join(", ")}` : ""}`
}
