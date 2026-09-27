require "httparty"
require "nokogiri"

module Nepse
  module Source
    class SharesansarMarketClient
      URL = "https://www.sharesansar.com/today-share-price".freeze
      REQUEST_TIMEOUT = 30
      USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze

      def fetch
        response = HTTParty.get(URL, headers: { "User-Agent" => USER_AGENT }, timeout: REQUEST_TIMEOUT)
        return { success: false, error: { code: :http_error, message: "HTTP #{response.code}" } } unless response.success?

        parse(response.body)
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        { success: false, error: { code: :request_failed, message: e.message } }
      end

      def parse(html, traded_on: Date.current, fetched_at: Time.current)
        table = find_market_table(Nokogiri::HTML(html))
        return missing_table_error unless table

        headers = table.css("thead th").map { |header| normalize_header(header.text) }
        rows = table.css("tbody tr").filter_map do |row|
          parse_row(row, headers, traded_on: traded_on, fetched_at: fetched_at)
        end

        { success: true, rows: rows }
      end

      private

      def find_market_table(doc)
        doc.css("table").find do |table|
          headers = table.css("thead th").map { |header| normalize_header(header.text) }
          headers.include?("symbol") && (headers.include?("ltp") || headers.include?("lasttradedprice"))
        end
      end

      def parse_row(row, headers, traded_on:, fetched_at:)
        values = row.css("td").map { |cell| cell.text.to_s.strip }
        fields = headers.zip(values).to_h

        symbol = fields["symbol"].to_s.upcase.strip
        last_price = numeric_value(fields["ltp"] || fields["lasttradedprice"] || fields["close"])
        return if symbol.blank? || last_price.nil?

        {
          symbol: symbol,
          open_price: numeric_value(fields["open"]),
          high_price: numeric_value(fields["high"]),
          low_price: numeric_value(fields["low"]),
          close_price: last_price,
          last_price: last_price,
          previous_close: numeric_value(fields["prevclose"] || fields["previousclose"]),
          change_amount: numeric_value(fields["diff"] || fields["pointchange"] || fields["change"]),
          change_percent: numeric_value(fields["%change"] || fields["diff%"] || fields["percentchange"] || fields["percentagechange"]),
          volume: integer_value(fields["qty"] || fields["vol"] || fields["volume"]),
          turnover: numeric_value(fields["turnover"]),
          total_trades: integer_value(fields["nooftransactions"] || fields["trans"] || fields["totaltrades"] || fields["trades"]),
          high_52w: numeric_value(fields["52weekshigh"] || fields["52wh"]),
          low_52w: numeric_value(fields["52weekslow"] || fields["52wl"]),
          traded_on: traded_on,
          fetched_at: fetched_at
        }
      end

      def missing_table_error
        {
          success: false,
          error: {
            code: :table_missing,
            message: "Sharesansar market table not found"
          }
        }
      end

      def normalize_header(text)
        text.to_s.downcase.gsub(/[^a-z0-9%]/, "")
      end

      def numeric_value(value)
        cleaned = cleaned_number(value)
        return if cleaned.nil?

        cleaned.to_f
      end

      def integer_value(value)
        cleaned = cleaned_number(value)
        return if cleaned.nil?

        cleaned.to_i
      end

      def cleaned_number(value)
        text = value.to_s.delete(",").delete("% ").strip
        return if text.blank? || text == "-"
        return unless text.match?(/\A-?\d+(?:\.\d+)?\z/)

        text
      end
    end
  end
end
