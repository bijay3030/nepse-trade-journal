require "httparty"

module Nepse
  module DataProviders
    class HistoricalDataProvider < BaseProvider
      DEFAULT_BASE_URL = "https://shubhamnpk.github.io/yonepse".freeze
      REQUEST_TIMEOUT = 15
      USER_AGENT = "NEPSE-Trade-Journal/1.0 (Historical Fetcher)".freeze

      attr_reader :base_url

      def initialize(base_url: nil)
        @base_url = (base_url || ENV["NEPSE_HISTORICAL_BASE_URL"] || DEFAULT_BASE_URL).chomp("/")
      end

      def fetch_daily_prices(date = Date.current)
        endpoint = "#{base_url}/data/history/#{date.strftime('%Y-%m-%d')}.json"
        response = execute_request(endpoint)

        if response[:success]
          raw_items = extract_items(response[:body])
          records = raw_items.filter_map { |item| normalize_item(item, fallback_date: date) }
          { success: true, provider: :historical, date: date, records: records, valid_count: records.size }
        else
          # Fall back to single daily price endpoint if historical date endpoint is absent
          fallback_provider = YonepseProvider.new(base_url: base_url)
          fallback_provider.fetch_daily_prices(date)
        end
      end

      def fetch_historical_prices(symbol, start_date: 365.days.ago.to_date, end_date: Date.current)
        normalized_symbol = symbol.to_s.strip.upcase
        endpoint = "#{base_url}/data/history/stocks/#{normalized_symbol}.json"
        response = execute_request(endpoint)

        return { success: false, error: response[:error], records: [] } unless response[:success]

        raw_items = extract_items(response[:body])
        return { success: false, error: "Empty history payload for #{normalized_symbol}", records: [] } if raw_items.empty?

        records = raw_items.filter_map do |item|
          normalized = normalize_item(item, symbol_override: normalized_symbol)
          next unless normalized&.valid?
          next if start_date && normalized.traded_on < start_date
          next if end_date && normalized.traded_on > end_date

          normalized
        end.sort_by(&:traded_on)

        {
          success: true,
          provider: :historical,
          symbol: normalized_symbol,
          records: records,
          valid_count: records.size
        }
      end

      private

      def execute_request(url)
        res = HTTParty.get(
          url,
          headers: { "User-Agent" => USER_AGENT, "Accept" => "application/json" },
          timeout: REQUEST_TIMEOUT
        )

        if res.success?
          { success: true, body: res.parsed_response }
        else
          { success: false, error: "HTTP error #{res.code}: #{res.message}" }
        end
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        Rails.logger.error("HistoricalDataProvider fetch failed for #{url}: #{e.message}")
        { success: false, error: "Network error: #{e.message}" }
      rescue JSON::ParserError => e
        Rails.logger.error("HistoricalDataProvider JSON parse failed for #{url}: #{e.message}")
        { success: false, error: "Malformed JSON response: #{e.message}" }
      end

      def extract_items(body)
        return [] if body.nil?
        return body if body.is_a?(Array)
        return body["data"] if body.is_a?(Hash) && body["data"].is_a?(Array)
        return body["history"] if body.is_a?(Hash) && body["history"].is_a?(Array)
        return body["rows"] if body.is_a?(Hash) && body["rows"].is_a?(Array)

        []
      end

      def normalize_item(item, symbol_override: nil, fallback_date: Date.current)
        return unless item.is_a?(Hash)

        symbol = symbol_override || item["symbol"] || item["Symbol"] || item["stockSymbol"]
        traded_date = item["tradedDate"] || item["date"] || item["traded_on"] || fallback_date

        close_price = item["close"] || item["closePrice"] || item["lastTradedPrice"] || item["ltp"]
        open_price = item["open"] || item["openPrice"]
        high_price = item["high"] || item["highPrice"] || item["maxPrice"]
        low_price = item["low"] || item["lowPrice"] || item["minPrice"]
        prev_close = item["previousClose"] || item["prevClose"]
        change_amt = item["change"] || item["difference"]
        change_pct = item["percentChange"] || item["percentageChange"]
        volume = item["volume"] || item["totalTradedQuantity"] || item["qty"]
        turnover = item["turnover"] || item["totalTradedValue"] || item["amount"]
        total_trades = item["totalTrades"] || item["trades"]
        company_name = item["companyName"] || item["name"]
        sector = item["sector"]

        normalized = NormalizedMarketData.new(
          symbol: symbol,
          company_name: company_name,
          sector: sector,
          traded_on: traded_date,
          open_price: open_price,
          high_price: high_price,
          low_price: low_price,
          close_price: close_price,
          previous_close: prev_close,
          change_amount: change_amt,
          change_percent: change_pct,
          volume: volume,
          turnover: turnover,
          total_trades: total_trades,
          raw_payload: item
        )

        normalized.valid? ? normalized : nil
      end
    end
  end
end
