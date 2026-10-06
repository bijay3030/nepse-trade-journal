module Setups
  # The volume signatures and base count stored on a snapshot, with their flags combined.
  module Signals
    module_function

    def call(bars, sma_50: nil)
      volume = VolumeSignals.call(bars: bars, sma_50: sma_50)
      base = BaseCount.call(bars.map(&:close_price))
      {
        up_down_ratio: volume[:up_down_ratio], pocket_pivot_age: volume[:pocket_pivot_age], dry_up_days: volume[:dry_up_days],
        base_number: base[:base_number], base_partial: base[:partial], in_base: base[:in_base], base_depth_pct: base[:depth_pct],
        flags: Array(volume[:flags]) + Array(base[:flags])
      }
    end
  end
end
