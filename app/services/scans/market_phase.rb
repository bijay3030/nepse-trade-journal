module Scans
  # NEPSE's trend phase, as on Market Overview: the 20-session average of the index against
  # the 50-session one, with a BAND_PCT band (uptrend above it, downtrend below, sideways
  # inside). The scanner shows today's phase and how each signal did in each phase since
  # 2020 (Scans::CrossoverBacktest), from archived closes (MarketIndexArchive) followed by
  # the regular index history. It describes the index; it isn't a forecast.
  module MarketPhase
    PHASES = %w[uptrend sideways downtrend].freeze
    SHORT = 20
    LONG = 50
    BAND_PCT = 1.0
    SYMBOL = "NEPSE"

    module_function

    # Market Overview's rule. With fewer than LONG values the reference is the average
    # before the last SHORT ones (so a short history still gets a phase).
    def trend(values)
      return "sideways" if values.size < SHORT

      short = values.last(SHORT).sum.to_f / SHORT
      reference = values.size >= LONG ? values.last(LONG).sum.to_f / LONG : average(values.first(values.size - SHORT))
      return "sideways" unless reference

      band = BAND_PCT / 100
      short > reference * (1 + band) ? "uptrend" : short < reference * (1 - band) ? "downtrend" : "sideways"
    end

    # [[date, close], ...] oldest first: archived closes, then the regular ones (which win
    # on overlapping dates), up to `through`.
    def series(through: nil)
      index = MarketIndex.find_by(symbol: SYMBOL) or return []
      regular = index.histories.where("index_value > 0")
      regular = regular.where(traded_on: ..through) if through
      regular = regular.order(:traded_on).pluck(:traded_on, Arel.sql("index_value::float8 AS value"))
      first = regular.first&.first
      archived = MarketIndexArchive.where(market_index: index)
      archived = archived.where(traded_on: ...first) if first
      archived = archived.where(traded_on: ..through) if through
      archived.order(:traded_on).pluck(:traded_on, Arel.sql("index_value::float8 AS value")) + regular
    end

    # { date => phase } for every session with LONG closes behind it.
    def timeline(series = self.series)
      values = series.map(&:last)
      series.each_with_index.filter_map { |(date, _), i| [ date, trend(values[0..i]) ] if i + 1 >= LONG }.to_h
    end

    # The phase on the latest session up to as_of, and how long it has lasted.
    def current(as_of: nil)
      points = series(through: as_of)
      return { phase: nil } if points.size < SHORT

      values = points.map(&:last)
      phase = trend(values)
      sessions = 1
      sessions += 1 while sessions < points.size - LONG && trend(values[0...(values.size - sessions)]) == phase
      {
        phase: phase, as_of: points.last.first, sessions: sessions,
        sma20: (values.last(SHORT).sum / SHORT).round(2), sma50: values.size >= LONG ? (values.last(LONG).sum / LONG).round(2) : nil,
        band_pct: BAND_PCT
      }
    end

    # Fills the archive with NEPSE closes from History::ARCHIVE_FROM up to the day before
    # the regular history. Returns the number of rows.
    def import!(client: Nepse::Source::MerolaganiHistoryClient.new)
      index = MarketIndex.find_by(symbol: SYMBOL) or return 0
      until_date = index.histories.minimum(:traded_on) || Date.current
      result = client.fetch(SYMBOL, from: History::ARCHIVE_FROM, to: until_date - 1)
      rows = Array(result[:bars]).select { _1[:traded_on] < until_date && _1[:close_price].to_f.positive? }
                                 .map { { market_index_id: index.id, traded_on: _1[:traded_on], index_value: _1[:close_price] } }
      MarketIndexArchive.upsert_all(rows, unique_by: %i[market_index_id traded_on]) if rows.any?
      rows.size
    end

    def average(values)
      values.empty? ? nil : values.sum.to_f / values.size
    end
  end
end
