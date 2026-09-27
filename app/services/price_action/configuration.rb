module PriceAction
  class Configuration
    DEFAULT_SWING_SENSITIVITY = 5
    DEFAULT_SR_TOLERANCE_PCT = 2.0
    DEFAULT_BREAKOUT_TOLERANCE_PCT = 1.5
    DEFAULT_MIN_SR_TOUCHES = 2

    attr_accessor :swing_sensitivity, :sr_tolerance_pct, :breakout_tolerance_pct, :min_sr_touches

    def initialize(
      swing_sensitivity: DEFAULT_SWING_SENSITIVITY,
      sr_tolerance_pct: DEFAULT_SR_TOLERANCE_PCT,
      breakout_tolerance_pct: DEFAULT_BREAKOUT_TOLERANCE_PCT,
      min_sr_touches: DEFAULT_MIN_SR_TOUCHES
    )
      @swing_sensitivity = [swing_sensitivity.to_i, 1].max
      @sr_tolerance_pct = [sr_tolerance_pct.to_f, 0.1].max
      @breakout_tolerance_pct = [breakout_tolerance_pct.to_f, 0.1].max
      @min_sr_touches = [min_sr_touches.to_i, 1].max
    end
  end
end
