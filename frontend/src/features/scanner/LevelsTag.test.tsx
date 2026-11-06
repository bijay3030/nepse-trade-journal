import { render, screen } from "@testing-library/react"

import { levelState } from "./levels"
import { LevelsTag } from "./LevelsTag"
import type { RowLevels } from "./types"

const levels: RowLevels = { entry_low: 500, entry_high: 515, stop: 470, target: 560, source: "board_setup", setup_type: "vcp" }

describe("LevelsTag", () => {
  it("places the price against the levels", () => {
    expect(levelState(505, levels).text).toBe("In entry zone")
    expect(levelState(490, levels).text).toBe("Wait: 2.0% below entry")
    expect(levelState(530, levels).text).toBe("Extended +2.9% (chasing)")
    expect(levelState(470, levels).text).toBe("Below stop")
  })

  it("shows entry, stop and target with the rule they came from, using a newer live price", () => {
    const live = { symbol: "NABIL", lastPrice: 508, changePercent: 1, volume: 1, updatedAt: "2026-11-06T07:00:00Z", flashDirection: null, flashTs: 0 }
    render(<LevelsTag levels={levels} close={530} asOf="2026-11-05" live={live} />)

    const tag = screen.getByLabelText("Levels")
    expect(tag).toHaveTextContent("In entry zone") // live 508, not the 530 close
    expect(tag).toHaveTextContent("Entry 500.00–515.00 · Stop 470.00 · Target 560.00")
    expect(tag).toHaveTextContent("VCP levels")
  })

  it("labels the crossover rule and falls back to the close", () => {
    render(<LevelsTag levels={{ ...levels, source: "crossover", setup_type: null }} close={530} asOf="2026-11-05" />)
    expect(screen.getByLabelText("Levels")).toHaveTextContent("Extended +2.9% (chasing)")
    expect(screen.getByLabelText("Levels")).toHaveTextContent("crossover rule")
  })
})
