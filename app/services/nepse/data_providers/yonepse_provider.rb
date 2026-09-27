require "httparty"

module Nepse
  module DataProviders
    class YonepseProvider < BaseProvider
      DEFAULT_BASE_URL = "https://shubhamnpk.github.io/yonepse".freeze
      REQUEST_TIMEOUT = 10
      USER_AGENT = "NEPSE-Trade-Journal/1.0 (Macintosh; Intel Mac OS X 10_15_7)".freeze

      attr_reader :base_url

      def initialize(base_url: nil)
        @base_url = (base_url || ENV["YONEPSE_BASE_URL"] || DEFAULT_BASE_URL).chomp("/")
      end

      def fetch_daily_prices(date = Date.current)
        endpoint = "#{base_url}/data/today_price.json"
        response = execute_request(endpoint)

        return { success: false, error: response[:error], records: [] } unless response[:success]

        raw_items = extract_items_from_response(response[:body])
        return { success: false, error: "Empty or invalid market data payload", records: [] } if raw_items.empty?

        records = raw_items.filter_map do |item|
          normalized = normalize_item(item, date: date)
          normalized if normalized.valid?
        end

        {
          success: true,
          provider: :yonepse,
          date: date,
          records: records,
          total_fetched: raw_items.size,
          valid_count: records.size
        }
      end

      def fetch_stock_metadata
        endpoint = "#{base_url}/data/company_list.json"
        response = execute_request(endpoint)

        return { success: false, error: response[:error], metadata: [] } unless response[:success]

        raw_items = extract_items_from_response(response[:body])
        metadata = raw_items.filter_map do |item|
          symbol = item["symbol"] || item["Symbol"] || item["stockSymbol"]
          next if symbol.blank?

          {
            symbol: symbol.to_s.strip.upcase,
            company_name: item["name"] || item["companyName"] || item["CompanyName"] || symbol,
            sector: item["sector"] || item["Sector"] || "Others",
            security_type: item["securityType"] || item["instrumentType"] || "Equity",
            is_active: item.fetch("isActive", true)
          }
        end

        { success: true, metadata: metadata }
      end

      def fetch_market_summary
        endpoint = "#{base_url}/data/indices.json"
        response = execute_request(endpoint)
        return { success: false, error: response[:error] } unless response[:success]

        { success: true, payload: response[:body] }
      end

      private

      def execute_request(url)
        res = HTTParty.get(
          url,
          headers: { "User-Agent" => USER_AGENT, "Accept" => "application/json" },
          timeout: REQUEST_TIMEOUT
        )

        if res.success?
          body = res.parsed_response
          { success: true, body: body }
        else
          { success: false, error: "HTTP error #{res.code}: #{res.message}" }
        end
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        Rails.logger.error("YonepseProvider fetch failed for #{url}: #{e.message}")
        { success: false, error: "Network error: #{e.message}" }
      rescue JSON::ParserError => e
        Rails.logger.error("YonepseProvider JSON parse failed for #{url}: #{e.message}")
        { success: false, error: "Malformed JSON response: #{e.message}" }
      end

      def extract_items_from_response(body)
        return [] if body.nil?
        return body if body.is_a?(Array)
        return body["data"] if body.is_a?(Hash) && body["data"].is_a?(Array)
        return body["content"] if body.is_a?(Hash) && body["content"].is_a?(Array)
        return body["rows"] if body.is_a?(Hash) && body["rows"].is_a?(Array)

        []
      end

      def normalize_item(item, date:)
        return NormalizedMarketData.new unless item.is_a?(Hash)

        symbol = item["symbol"] || item["Symbol"] || item["stockSymbol"] || item["ticker"]
        close_price = item["close"] || item["closePrice"] || item["lastTradedPrice"] || item["ltp"] || item["lastPrice"]
        open_price = item["open"] || item["openPrice"]
        high_price = item["high"] || item["highPrice"] || item["maxPrice"]
        low_price = item["low"] || item["lowPrice"] || item["minPrice"]
        prev_close = item["previousClose"] || item["prevClose"] || item["previousClosePrice"]
        change_amt = item["change"] || item["difference"] || item["pointChange"]
        change_pct = item["percentChange"] || item["percentageChange"] || item["changePercent"]
        volume = item["volume"] || item["totalTradedQuantity"] || item["qty"] || item["quantity"]
        turnover = item["turnover"] || item["totalTradedValue"] || item["amount"]
        total_trades = item["totalTrades"] || item["numberOfTransactions"] || item["trades"]
        company_name = item["companyName"] || item["name"] || item["company"]
        sector = item["sector"] || item["sectorName"]

        traded_date = item["tradedDate"] || item["date"] || date

        NormalizedMarketData.new(
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
      end
    end
  end
end
