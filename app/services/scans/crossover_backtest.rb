module Scans
  # How each Scans::Crossovers signal played out on our NEPSE history: every session
  # where a signal began (the cross, the turn, the stack forming) is a sample, and its
  # return over the next 5, 10 and 20 sessions (close to close, before costs) is
  # compared with NEPSE over the same sessions and with all stock-days (the baseline).
  # Indicators only use bars up to the signal day, so there's no look-ahead.
  module CrossoverBacktest
    HORIZONS = [ 5, 10, 20 ].freeze

    module_function

    def call(now: Time.current)
      bars = Crossovers.load_bars(now)
      nepse = MarketIndexHistory.joins(:market_index).where(market_indices: { symbol: "NEPSE" }).pluck(:traded_on, :index_value).to_h { [ _1, _2.to_f ] }
      samples = Hash.new { |h, k| h[k] = [] }
      dates = []

      bars.each_value do |rows|
        next if rows.size < Crossovers::MIN_BARS

        series = Crossovers.compute(rows)
        closes = series[:close]
        dates.concat(series[:dates])
        forward = ->(i) { HORIZONS.to_h { |h| [ h, sample(series[:dates], closes, nepse, i, h) ] } }
        (0...closes.size).each { |i| samples["all"] << forward.(i) if closes[i].positive? }
        Crossovers::SIGNALS.each do |signal|
          Crossovers.onsets(series, signal).each { |i| samples[signal] << forward.(i) }
        end
      end

      {
        period: { from: dates.min, to: dates.max }, horizons: HORIZONS,
        signals: ([ "all" ] + Crossovers::SIGNALS).to_h { |key| [ key, HORIZONS.to_h { |h| [ h, stats(samples[key].filter_map { _1[h] }) ] } ] }
      }
    end

    # [return %, excess over NEPSE %] h sessions after bar i, or nil near the end.
    def sample(dates, closes, nepse, i, h)
      j = i + h
      return if j >= closes.size || !closes[i].positive?

      stock = (closes[j] / closes[i] - 1) * 100
      a, b = nepse[dates[i]], nepse[dates[j]]
      [ stock, a && b ? stock - (b / a - 1) * 100 : nil ]
    end

    def stats(values)
      return { n: 0 } if values.empty?

      returns = values.map(&:first).sort
      excess = values.filter_map(&:last)
      {
        n: values.size,
        avg_return_pct: (returns.sum / returns.size).round(2),
        median_return_pct: returns[returns.size / 2].round(2),
        win_rate_pct: (returns.count(&:positive?) * 100.0 / returns.size).round(1),
        avg_excess_pct: excess.empty? ? nil : (excess.sum / excess.size).round(2)
      }
    end
  end
end
