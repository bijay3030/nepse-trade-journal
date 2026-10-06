module Setups
  # Market direction from the NEPSE index, IBD-style: distribution days, rally
  # attempts and follow-through days turn into one of three states.
  #
  #   distribution day  index closes down DOWN_PCT or more on higher turnover than the
  #                     session before. It stops counting after EXPIRY_SESSIONS sessions,
  #                     or once the index closes RALLY_EXPIRY_PCT above that day's close.
  #   uptrend           the default after a follow-through day
  #   under_pressure    PRESSURE_DAYS or more distribution days are counting
  #   correction        CORRECTION_DAYS or more, or the index has fallen CORRECTION_DRAWDOWN_PCT
  #                     from its high since the last follow-through ("no new buys" in IBD terms)
  #   follow-through    in a correction, a rally attempt starts on the first up close after
  #                     the low; from its FOLLOW_THROUGH_FROM-th day a gain of UP_PCT or more
  #                     on higher turnover ends the correction. Closing below the attempt's
  #                     low restarts the attempt.
  #
  # Thresholds: IBD uses 0.2% / 1.2% for US indexes; NEPSE moves about twice as much
  # (median day 0.47%), so THRESHOLDS also has a NEPSE-scaled set. Which one is used is
  # decided by the backtest (see THRESHOLD_SET).
  #
  # It describes the index; it is not a forecast or advice. Shown on Market Overview and
  # the board; outside an uptrend the sizing aid also shows a cautious size (SIZE_FACTORS
  # of the usual risk) next to the normal one. Nothing is reduced automatically: in the
  # Apr-Oct 2026 backtest neither threshold set predicted later returns (stocks did best
  # during the June correction, buying its rebound), so the trader decides.
  #
  # THRESHOLD_SET: IBD's 0.2% flagged "under pressure" on 108 of 232 sessions, too
  # sensitive for NEPSE, so the NEPSE-scaled set is used.
  module MarketDirection
    THRESHOLDS = {
      "ibd" => { down_pct: 0.2, up_pct: 1.2 },
      "nepse" => { down_pct: 0.5, up_pct: 1.5 }
    }.freeze
    THRESHOLD_SET = "nepse"
    EXPIRY_SESSIONS = 25
    RALLY_EXPIRY_PCT = 5.0
    PRESSURE_DAYS = 4
    CORRECTION_DAYS = 6
    CORRECTION_DRAWDOWN_PCT = 10.0
    FOLLOW_THROUGH_FROM = 4
    STATES = %w[uptrend under_pressure correction].freeze
    SIZE_FACTORS = { "uptrend" => 1.0, "under_pressure" => 0.5, "correction" => 0.25 }.freeze
    LABELS = { "uptrend" => "Uptrend", "under_pressure" => "Uptrend under pressure", "correction" => "Correction" }.freeze

    module_function

    # The state on each session: { date => result }. series: [[date, close, turnover], ...] oldest first.
    def timeline(series, down_pct: THRESHOLDS[THRESHOLD_SET][:down_pct], up_pct: THRESHOLDS[THRESHOLD_SET][:up_pct])
      state = "uptrend"
      cycle_high = nil
      active = [] # [index, date, close]
      attempt = nil # { low:, day: }
      follow_through_on = nil
      out = {}

      series.each_with_index do |(date, close, turnover), i|
        close = close.to_f
        prev_close = i.positive? ? series[i - 1][1].to_f : nil
        change = prev_close&.positive? ? (close / prev_close - 1) * 100 : 0.0
        higher_turnover = i.positive? && turnover.to_f > series[i - 1][2].to_f
        cycle_high = [ cycle_high || close, close ].max

        active.reject! { |idx, _, day_close| i - idx >= EXPIRY_SESSIONS || close >= day_close * (1 + RALLY_EXPIRY_PCT / 100) }
        active << [ i, date, close ] if change <= -down_pct && higher_turnover
        drawdown = (close / cycle_high - 1) * 100

        if state == "correction"
          if attempt.nil? || close < attempt[:low]
            attempt = { low: close, day: 0 } # a new low: the attempt starts again
          elsif attempt[:day].zero? ? change.positive? : true
            attempt[:day] += 1
            if attempt[:day] >= FOLLOW_THROUGH_FROM && change >= up_pct && higher_turnover
              state = "uptrend"
              follow_through_on = date
              active.clear
              cycle_high = close
              attempt = nil
            end
          end
        elsif active.size >= CORRECTION_DAYS || drawdown <= -CORRECTION_DRAWDOWN_PCT
          state = "correction"
          attempt = { low: close, day: 0 }
        else
          state = active.size >= PRESSURE_DAYS ? "under_pressure" : "uptrend"
        end

        out[date] = {
          state: state, distribution_days: active.size, distribution_dates: active.map { _2 },
          drawdown_pct: ((close / cycle_high - 1) * 100).round(2), rally_day: attempt && attempt[:day],
          follow_through_on: follow_through_on
        }
      end
      out
    end

    # NEPSE's index history as [[date, close, turnover], ...], up to as_of.
    def nepse_series(as_of: nil)
      scope = MarketIndexHistory.joins(:market_index).where(market_indices: { symbol: "NEPSE" })
      scope = scope.where(traded_on: ..as_of) if as_of
      scope.order(:traded_on).pluck(:traded_on, :index_value, :turnover)
    end

    # The latest state, cached until a new index session arrives.
    def current
      latest = MarketIndexHistory.joins(:market_index).where(market_indices: { symbol: "NEPSE" }).maximum(:traded_on)
      return unless latest

      Rails.cache.fetch("setups:market_direction:#{latest}:#{THRESHOLD_SET}", expires_in: 12.hours) { call }
    end

    # The state on the latest session up to as_of, with its label and size factor.
    def call(as_of: nil)
      series = nepse_series(as_of: as_of)
      return if series.empty?

      date, result = timeline(series).max_by(&:first)
      result.merge(traded_on: date, label: LABELS[result[:state]], size_factor: SIZE_FACTORS[result[:state]],
                   threshold_set: THRESHOLD_SET, thresholds: THRESHOLDS[THRESHOLD_SET])
    end
  end
end
