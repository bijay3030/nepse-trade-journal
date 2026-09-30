require "httparty"

module Nepse
  module Source
    # Chukul's public JSON API (the endpoints its own site calls without logging in).
    # Endpoints that need an account, such as /data/v2/fundamentals/, are not used.
    class ChukulClient
      BASE_URL = "https://chukul.com/api".freeze
      REQUEST_TIMEOUT = 20
      USER_AGENT = MerolaganiCompanyClient::USER_AGENT
      NPT_OFFSET = 5 * 3600 + 45 * 60

      def companies = get("/stock/")
      def sectors = get("/sector/")
      def dividends(symbol) = get("/bonus/", { symbol: symbol.to_s.upcase })
      def brokers = get("/broker/")

      # Every trade of one session: symbol, buyer and seller broker numbers,
      # quantity, rate and amount (~8 MB, ~60k trades).
      def floorsheet(date) = get("/data/floorsheet/bydate/", { date: date.iso8601 }, timeout: 90)

      # Latest fundamentals for one security. Needs Chukul's own sector id.
      def stock_details(symbol, sector_id)
        get("/data/stock-details/", { symbol: symbol.to_s.upcase, sector: sector_id })
      end

      # Daily bars for an index or a stock. Chukul stamps each bar at midnight Nepal
      # time of its session, so the session date is the Nepal-time date.
      def history(symbol, from:, to:)
        response = get("/data/historydata/data/", { symbol: symbol, from: from.to_time(:utc).to_i, to: (to + 1).to_time(:utc).to_i })
        return response unless response[:success]

        data = response[:data]
        return { success: false, error: "No history for #{symbol}" } unless data.is_a?(Hash) && Array(data["t"]).any?

        bars = data["t"].each_with_index.filter_map do |timestamp, index|
          close = data.dig("c", index).to_f
          next unless close.positive?

          {
            traded_on: Time.at(timestamp.to_i + NPT_OFFSET).utc.to_date,
            open: data.dig("o", index).to_f, high: data.dig("h", index).to_f, low: data.dig("l", index).to_f,
            close: close, volume: data.dig("vol", index).to_f, turnover: data.dig("amt", index).to_f
          }
        end
        { success: true, bars: bars.sort_by { _1[:traded_on] }.uniq { _1[:traded_on] } }
      end

      private

      def get(path, query = {}, timeout: REQUEST_TIMEOUT)
        response = HTTParty.get(
          "#{BASE_URL}#{path}",
          query: query,
          headers: { "User-Agent" => USER_AGENT, "Accept" => "application/json" },
          timeout: timeout
        )
        return { success: false, error: "HTTP #{response.code}" } unless response.success?

        { success: true, data: JSON.parse(response.body) }
      rescue JSON::ParserError
        { success: false, error: "Response was not JSON" }
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        { success: false, error: e.message }
      end
    end
  end
end
