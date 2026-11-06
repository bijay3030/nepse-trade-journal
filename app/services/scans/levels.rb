module Scans
  # Entry, stop and target for an Indicator Scanner row. A stock with a setup in the
  # nightly snapshot (the board's tested rules) uses that setup's levels; otherwise the
  # crossover rule, measured in the stock's own average daily range (ADR):
  #
  #   entry   the signal-day close to 1 ADR above it
  #   stop    just under EMA 21 (1% below it) when that's under the entry, else 2 ADR
  #           below the entry; never more than MAX_STOP_PCT below it
  #   target  entry + REWARD_MULTIPLE × the risk (entry low to stop)
  #
  # Scans::CrossoverBacktest trades these levels on history. Rule output, not advice.
  module Levels
    ADR_SESSIONS = 20
    MAX_STOP_PCT = 8.0
    REWARD_MULTIPLE = 2.0
    EMA_BUFFER = 0.99
    SETUP_STATES = %w[too_early in_zone extended].freeze

    module_function

    # Levels on bar i of a Crossovers.compute series, or nil without enough history.
    def crossover(series, i)
      close = series[:close][i]
      adr = adr_pct(series, i)
      return unless close&.positive? && adr

      low = close
      high = close * (1 + adr / 100)
      ema = series[:ema21][i]
      stop = ema && ema * EMA_BUFFER < low ? ema * EMA_BUFFER : low * (1 - 2 * adr / 100)
      stop = [ stop, low * (1 - MAX_STOP_PCT / 100) ].max
      { entry_low: low.round(2), entry_high: high.round(2), stop: stop.round(2),
        target: (low + REWARD_MULTIPLE * (low - stop)).round(2), source: "crossover", setup_type: nil }
    end

    # The snapshot setup's levels when it has a live setup, else nil.
    def board(snapshot)
      return unless snapshot && snapshot[:setup_type] && SETUP_STATES.include?(snapshot[:zone_state]) && snapshot[:entry_zone_low]

      { entry_low: snapshot[:entry_zone_low].to_f.round(2), entry_high: snapshot[:entry_zone_high].to_f.round(2),
        stop: snapshot[:invalidation_price].to_f.round(2), target: snapshot[:target_price]&.to_f&.round(2),
        source: "board_setup", setup_type: snapshot[:setup_type] }
    end

    def adr_pct(series, i)
      return if i < ADR_SESSIONS - 1

      window = ((i - ADR_SESSIONS + 1)..i).map { |j| series[:low][j].positive? ? series[:high][j] / series[:low][j] - 1 : nil }.compact
      window.size >= ADR_SESSIONS / 2 ? window.sum / window.size * 100 : nil
    end
  end
end
