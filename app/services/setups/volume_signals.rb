module Setups
  # Volume signatures around an entry (O'Neil, Morales/Kacher), point in time:
  #
  #   up_down_ratio     volume on up-close days / volume on down-close days over the last
  #                     UD_SESSIONS sessions; 1.2+ suggests accumulation, under 0.8 distribution
  #   pocket_pivot_age  sessions since the latest pocket pivot in the last POCKET_LOOKBACK:
  #                     an up close on more volume than any down day in the 10 sessions before,
  #                     closing near the 10-day average (0-5% above it) or within 3% of the 50-day
  #   dry_up_days       sessions in the last DRY_UP_SESSIONS (before the session) on volume
  #                     under half the 50-day average: sellers going quiet in the base
  #
  # Thin stocks distort these (one block trade swings a ratio), so they're only measured
  # with MIN_TRADED_SESSIONS of volume. Information only until the backtest says otherwise.
  module VolumeSignals
    UD_SESSIONS = 50
    POCKET_LOOKBACK = 5
    DRY_UP_SESSIONS = 10
    DRY_UP_SHARE = 0.5
    DRY_UP_MIN_DAYS = 2
    MIN_TRADED_SESSIONS = 40
    STRONG_UD = 1.2
    WEAK_UD = 0.8

    module_function

    # bars: prices (close_price, volume) oldest first ending at the session; sma_50 from indicators.
    def call(bars:, sma_50: nil)
      recent = bars.last(UD_SESSIONS + 1)
      return {} if recent.count { _1.volume.to_i.positive? } < MIN_TRADED_SESSIONS

      ratio = up_down_ratio(recent)
      age = pocket_pivot_age(bars, sma_50)
      dry = dry_up_days(bars)
      flags = []
      flags << "pocket_pivot" if age
      flags << "strong_up_down" if ratio && ratio >= STRONG_UD
      flags << "weak_up_down" if ratio && ratio < WEAK_UD
      flags << "dry_up" if dry && dry >= DRY_UP_MIN_DAYS
      { up_down_ratio: ratio, pocket_pivot_age: age, dry_up_days: dry, flags: flags }
    end

    def up_down_ratio(bars)
      up = down = 0
      bars.each_cons(2) do |previous, bar|
        if bar.close_price.to_f > previous.close_price.to_f then up += bar.volume.to_i
        elsif bar.close_price.to_f < previous.close_price.to_f then down += bar.volume.to_i
        end
      end
      down.positive? ? (up.to_f / down).round(2) : nil
    end

    def pocket_pivot_age(bars, sma_50)
      (0...POCKET_LOOKBACK).each do |age|
        i = bars.size - 1 - age
        return age if i >= 11 && pocket_pivot?(bars, i, age.zero? ? sma_50 : nil)
      end
      nil
    end

    # sma_50 is only known for the session itself; earlier days use the 10-day test alone.
    def pocket_pivot?(bars, i, sma_50)
      bar = bars[i]
      close = bar.close_price.to_f
      return false unless close > bars[i - 1].close_price.to_f

      down_volumes = (i - 10...i).filter_map { |j| bars[j].volume.to_i if bars[j].close_price.to_f < bars[j - 1].close_price.to_f }
      return false unless bar.volume.to_i > (down_volumes.max || 0)

      sma_10 = bars[i - 9..i].sum { _1.close_price.to_f } / 10
      near_10 = close >= sma_10 && close <= sma_10 * 1.05
      near_50 = sma_50.to_f.positive? && (close / sma_50.to_f - 1).abs <= 0.03
      near_10 || near_50
    end

    def dry_up_days(bars)
      return if bars.size < UD_SESSIONS + 1

      average = bars[-(UD_SESSIONS + 1)...-1].sum { _1.volume.to_i } / UD_SESSIONS.to_f
      return unless average.positive?

      bars[-(DRY_UP_SESSIONS + 1)...-1].count { _1.volume.to_i < average * DRY_UP_SHARE }
    end
  end
end
