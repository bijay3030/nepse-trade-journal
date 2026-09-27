module Vcp
  class Configuration
    DEFAULT_MIN_BASE_DURATION_BARS = 15
    DEFAULT_MAX_BASE_DURATION_BARS = 120
    DEFAULT_MAX_T1_CONTRACTION_PCT = 35.0
    DEFAULT_MAX_FINAL_CONTRACTION_PCT = 10.0
    DEFAULT_PIVOT_PROXIMITY_PCT = 3.0
    DEFAULT_MIN_CONTRACTIONS = 2
    DEFAULT_SWING_SENSITIVITY = 3

    attr_accessor :min_base_duration_bars, :max_base_duration_bars,
                  :max_t1_contraction_pct, :max_final_contraction_pct,
                  :pivot_proximity_pct, :min_contractions, :swing_sensitivity

    def initialize(
      min_base_duration_bars: DEFAULT_MIN_BASE_DURATION_BARS,
      max_base_duration_bars: DEFAULT_MAX_BASE_DURATION_BARS,
      max_t1_contraction_pct: DEFAULT_MAX_T1_CONTRACTION_PCT,
      max_final_contraction_pct: DEFAULT_MAX_FINAL_CONTRACTION_PCT,
      pivot_proximity_pct: DEFAULT_PIVOT_PROXIMITY_PCT,
      min_contractions: DEFAULT_MIN_CONTRACTIONS,
      swing_sensitivity: DEFAULT_SWING_SENSITIVITY
    )
      @min_base_duration_bars = [min_base_duration_bars.to_i, 5].max
      @max_base_duration_bars = [max_base_duration_bars.to_i, @min_base_duration_bars].max
      @max_t1_contraction_pct = [max_t1_contraction_pct.to_f, 1.0].max
      @max_final_contraction_pct = [max_final_contraction_pct.to_f, 0.5].max
      @pivot_proximity_pct = [pivot_proximity_pct.to_f, 0.1].max
      @min_contractions = [min_contractions.to_i, 1].max
      @swing_sensitivity = [swing_sensitivity.to_i, 1].max
    end
  end
end
