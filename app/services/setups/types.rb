module Setups
  # The setup types the app recognises. Breakouts are judged against a pivot and
  # need volume to confirm; pullbacks are judged by holding their zone.
  module Types
    ALL = %w[vcp pullback ma_pullback base_breakout three_weeks_tight undercut_rally].freeze
    BREAKOUTS = %w[vcp base_breakout three_weeks_tight].freeze
    PULLBACKS = %w[pullback ma_pullback undercut_rally].freeze
    LABELS = {
      "vcp" => "VCP breakout",
      "pullback" => "Pullback to support",
      "ma_pullback" => "Pullback to a rising average",
      "base_breakout" => "Flat-base breakout",
      "three_weeks_tight" => "3-weeks-tight",
      "undercut_rally" => "Undercut and rally"
    }.freeze

    module_function

    def breakout?(type) = BREAKOUTS.include?(type.to_s)
    def label(type) = LABELS.fetch(type.to_s, type.to_s.tr("_", " "))
  end
end
