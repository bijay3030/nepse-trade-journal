module Vcp
  class Configuration
    DEFAULT_MIN_BASE_DURATION_BARS = 15
    DEFAULT_MAX_BASE_DURATION_BARS = 120
    DEFAULT_MAX_T1_CONTRACTION_PCT = 35.0
    DEFAULT_MAX_FINAL_CONTRACTION_PCT = 10.0
    DEFAULT_PIVOT_PROXIMITY_PCT = 3.0
    DEFAULT_MIN_CONTRACTIONS = 2
    DEFAULT_SWING_SENSITIVITY = 3
    # A swing is only recorded after price reverses by this multiple of the stock's
    # own median daily range (last 60 bars), kept between the floor and cap below.
    # A fixed 3% was about one ordinary day's range on NEPSE and recorded noise.
    DEFAULT_ZIGZAG_RANGE_MULTIPLE = 2.0
    DEFAULT_ZIGZAG_REVERSAL_PCT = 3.0
    DEFAULT_ZIGZAG_MAX_REVERSAL_PCT = 8.0
    # Real VCPs usually show 2-4 contractions; more is a choppy range.
    DEFAULT_MAX_CONTRACTIONS = 4
    # Each contraction's high may sit at most this far above the previous one.
    DEFAULT_MAX_HIGH_DRIFT_PCT = 2.0
    # The base must start with a meaningful correction...
    DEFAULT_MIN_T1_CONTRACTION_PCT = 8.0
    # ...and each contraction must be clearly shallower than the one before.
    DEFAULT_MAX_DEPTH_RATIO = 0.8

    attr_accessor :min_base_duration_bars, :max_base_duration_bars,
                  :max_t1_contraction_pct, :max_final_contraction_pct,
                  :pivot_proximity_pct, :min_contractions, :swing_sensitivity,
                  :zigzag_reversal_pct, :zigzag_range_multiple, :zigzag_max_reversal_pct,
                  :max_contractions, :max_high_drift_pct,
                  :min_t1_contraction_pct, :max_depth_ratio

    def initialize(
      min_base_duration_bars: DEFAULT_MIN_BASE_DURATION_BARS,
      max_base_duration_bars: DEFAULT_MAX_BASE_DURATION_BARS,
      max_t1_contraction_pct: DEFAULT_MAX_T1_CONTRACTION_PCT,
      max_final_contraction_pct: DEFAULT_MAX_FINAL_CONTRACTION_PCT,
      pivot_proximity_pct: DEFAULT_PIVOT_PROXIMITY_PCT,
      min_contractions: DEFAULT_MIN_CONTRACTIONS,
      swing_sensitivity: DEFAULT_SWING_SENSITIVITY,
      zigzag_reversal_pct: DEFAULT_ZIGZAG_REVERSAL_PCT,
      zigzag_range_multiple: DEFAULT_ZIGZAG_RANGE_MULTIPLE,
      zigzag_max_reversal_pct: DEFAULT_ZIGZAG_MAX_REVERSAL_PCT,
      max_contractions: DEFAULT_MAX_CONTRACTIONS,
      max_high_drift_pct: DEFAULT_MAX_HIGH_DRIFT_PCT,
      min_t1_contraction_pct: DEFAULT_MIN_T1_CONTRACTION_PCT,
      max_depth_ratio: DEFAULT_MAX_DEPTH_RATIO
    )
      @min_base_duration_bars = [min_base_duration_bars.to_i, 5].max
      @max_base_duration_bars = [max_base_duration_bars.to_i, @min_base_duration_bars].max
      @max_t1_contraction_pct = [max_t1_contraction_pct.to_f, 1.0].max
      @max_final_contraction_pct = [max_final_contraction_pct.to_f, 0.5].max
      @pivot_proximity_pct = [pivot_proximity_pct.to_f, 0.1].max
      @min_contractions = [min_contractions.to_i, 1].max
      # No longer used by contraction detection (see zigzag_reversal_pct); kept so
      # existing callers that pass it keep working.
      @swing_sensitivity = [swing_sensitivity.to_i, 1].max
      @zigzag_reversal_pct = [zigzag_reversal_pct.to_f, 0.5].max
      @zigzag_range_multiple = [zigzag_range_multiple.to_f, 0.0].max
      @zigzag_max_reversal_pct = [zigzag_max_reversal_pct.to_f, @zigzag_reversal_pct].max
      @max_contractions = [max_contractions.to_i, @min_contractions].max
      @max_high_drift_pct = [max_high_drift_pct.to_f, 0.0].max
      @min_t1_contraction_pct = [min_t1_contraction_pct.to_f, 0.0].max
      @max_depth_ratio = max_depth_ratio.to_f.clamp(0.1, 1.0)
    end
  end
end
