module Nepse
  module Reference
    # Cash dividend and bonus share history per security. Chukul first (it also has
    # announcement, book-close and AGM dates); Merolagani fills fiscal years Chukul lacks.
    class DividendSync
      def self.call(**options)
        new(**options).call
      end

      def initialize(symbols: nil, chukul: Source::ChukulClient.new, merolagani: Source::MerolaganiCompanyClient.new, delay_seconds: 0.2)
        @symbols = Array(symbols).map { _1.to_s.upcase }.presence
        @chukul = chukul
        @merolagani = merolagani
        @delay_seconds = delay_seconds.to_f
      end

      def call
        stocks = Stock.active.where(security_type: %w[Equity Mutual Fund]).order(:symbol)
        stocks = stocks.where(symbol: @symbols) if @symbols
        summary = { success: true, stocks: 0, rows: 0, from_merolagani: 0, none: [], failed: {} }

        stocks.each_with_index do |stock, index|
          sleep(@delay_seconds) if index.positive? && @delay_seconds.positive?
          rows = chukul_rows(stock)
          if rows.empty?
            rows = merolagani_rows(stock)
            summary[:from_merolagani] += 1 if rows.any?
          end
          next summary[:none] << stock.symbol if rows.empty?

          store(stock, rows)
          summary[:stocks] += 1
          summary[:rows] += rows.size
        rescue StandardError => e
          summary[:failed][stock.symbol] = e.message
        end

        summary
      end

      private

      def chukul_rows(stock)
        response = @chukul.dividends(stock.symbol)
        return [] unless response[:success] && response[:data].is_a?(Array)

        response[:data].filter_map do |row|
          year = fiscal_year(row["year"])
          next unless year

          {
            fiscal_year: year, cash_percent: row["cash"], bonus_percent: row["bonus"], total_percent: row["total"],
            announced_on: date(row["annoucement_date"] || row["announcement_date"]),
            book_close_on: date(row["book_close_date"]), agm_on: date(row["agm_date"]), source: "chukul"
          }
        end
      end

      def merolagani_rows(stock)
        result = @merolagani.details(stock.symbol)
        return [] unless result[:success]

        cash = result[:cash_dividends].index_by { _1[:fiscal_year] }
        bonus = result[:bonus_shares].index_by { _1[:fiscal_year] }
        (cash.keys | bonus.keys).map do |year|
          cash_pct = cash.dig(year, :percent)
          bonus_pct = bonus.dig(year, :percent)
          {
            fiscal_year: year, cash_percent: cash_pct, bonus_percent: bonus_pct,
            total_percent: (cash_pct.to_f + bonus_pct.to_f).round(2), source: "merolagani"
          }
        end
      end

      def store(stock, rows)
        now = Time.current
        StockDividend.upsert_all(
          rows.map { _1.merge(stock_id: stock.id, created_at: now, updated_at: now) },
          unique_by: %i[stock_id fiscal_year],
          update_only: %i[cash_percent bonus_percent total_percent announced_on book_close_on agm_on source]
        )
      end

      # "082/083" or "082-083" => "082/083"
      def fiscal_year(value)
        match = value.to_s.match(/(\d{3})\D(\d{3})/)
        "#{match[1]}/#{match[2]}" if match
      end

      def date(value)
        Date.iso8601(value.to_s) if value.to_s.match?(/\A\d{4}-\d{2}-\d{2}/)
      rescue Date::Error
        nil
      end
    end
  end
end
