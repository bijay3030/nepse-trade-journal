export const rupees = (value: number) => `Rs ${value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
export const signedRupees = (value: number) => `${value > 0 ? "+" : value < 0 ? "−" : ""}${rupees(Math.abs(value))}`
