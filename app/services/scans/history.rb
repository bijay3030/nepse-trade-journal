module Scans
  # Long daily history for the Indicator Scanner's track record: archived prices
  # (stock_price_archives, from ARCHIVE_FROM) followed by the stock's regular prices.
  #
  # import! fills the archive from Merolagani's adjusted history for the dates before
  # each stock's first regular price. Nothing else in the app reads the archive.
  module History
    ARCHIVE_FROM = Date.new(2020, 1, 1)
    DELAY_SECONDS = 0.3
    # Floats straight from SQL: BigDecimals for seven years of prices churn memory.
    COLUMNS = [ :stock_id, :traded_on, *%w[high_price low_price close_price open_price].map { Arel.sql("#{_1}::float8 AS #{_1}_f") }, :volume ].freeze

    module_function

    # Yields [stock_id, [[date, high, low, close, open, volume], ...]] oldest first, one
    # stock at a time (so all seven years are never in memory at once). Completed
    # sessions only, like Scans::Crossovers.
    def each_stock(now: Time.current)
      ids = Stock.active.where(security_type: "Equity").order(:id).pluck(:id)
      ids.each_slice(20) do |slice|
        archived = StockPriceArchive.where(stock_id: slice).order(:traded_on)
                                    .pluck(*COLUMNS).group_by(&:first)
        current = StockDailyPrice.where(stock_id: slice).where("close_price > 0")
        current = current.where(traded_on: ...Nepse::MarketHours.today(now)) if Nepse::MarketHours.sync_window?(now)
        current = current.order(:traded_on).pluck(*COLUMNS).group_by(&:first)
        slice.each do |id|
          recent = current.fetch(id, [])
          first_recent = recent.first&.at(1)
          old = archived.fetch(id, []).select { first_recent.nil? || _2 < first_recent }
          rows = (old + recent).map { |_, d, h, l, c, o, v| [ d, h || 0.0, l || 0.0, c, o || 0.0, v || 0 ] }
          yield id, rows if rows.any?
        end
      end
    end

    # Fills the archive for stocks (default: all active equities). Returns a summary.
    def import!(symbols: nil, client: Nepse::Source::MerolaganiHistoryClient.new, delay: DELAY_SECONDS)
      scope = Stock.active.where(security_type: "Equity").order(:symbol)
      scope = scope.where(symbol: symbols) if symbols
      summary = { stocks: 0, rows: 0, failed: {} }
      scope.each_with_index do |stock, index|
        sleep(delay) if index.positive? && delay.positive?
        until_date = stock.daily_prices.minimum(:traded_on) || Date.current
        next if until_date <= ARCHIVE_FROM

        result = client.fetch(stock.symbol, from: ARCHIVE_FROM, to: until_date - 1)
        bars = Array(result[:bars]).select { _1[:traded_on] < until_date && _1[:close_price].to_f.positive? }
        next summary[:failed][stock.symbol] = result[:error].presence || "no history" if bars.empty?

        rows = bars.map do |b|
          { stock_id: stock.id, traded_on: b[:traded_on], open_price: b[:open_price], high_price: b[:high_price], low_price: b[:low_price],
            close_price: b[:close_price], volume: b[:volume] }
        end
        StockPriceArchive.upsert_all(rows, unique_by: %i[stock_id traded_on])
        summary[:stocks] += 1
        summary[:rows] += rows.size
      rescue StandardError => e
        summary[:failed][stock.symbol] = e.message
      end
      summary
    end
  end
end
