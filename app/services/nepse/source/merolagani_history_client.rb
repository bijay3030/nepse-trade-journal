require "httparty"

module Nepse
  module Source
    # Daily OHLCV bars from Merolagani's chart endpoint (TradingView format).
    # Prices are adjusted for bonus and rights issues, which keeps older bars
    # comparable with today's price for pattern detection.
    #
    # Each bar is stamped around 20:44 UTC on its session date, so the session is
    # the UTC date of the timestamp (checked against Sharesansar's session table).
    class MerolaganiHistoryClient
      URL = "https://merolagani.com/handlers/TechnicalChartHandler.ashx".freeze
      REQUEST_TIMEOUT = 20
      USER_AGENT = MerolaganiCompanyClient::USER_AGENT

      def fetch(symbol, from: 365.days.ago.to_date, to: Date.current)
        response = HTTParty.get(
          URL,
          query: {
            type: "get_advanced_chart", symbol: symbol.to_s.upcase, resolution: "1D",
            rangeStartDate: from.to_time(:utc).to_i, rangeEndDate: (to + 1).to_time(:utc).to_i,
            from: "", isAdjust: 1, currencyCode: "NPR"
          },
          headers: { "User-Agent" => USER_AGENT, "Accept" => "application/json" },
          timeout: REQUEST_TIMEOUT
        )
        return { success: false, error: "HTTP #{response.code}" } unless response.success?

        parse(response.body)
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        { success: false, error: e.message }
      end

      def parse(body)
        data = JSON.parse(body.to_s)
        return { success: false, error: "No history (status #{data['s'].inspect})" } unless data.is_a?(Hash) && data["s"] == "ok"

        bars = Array(data["t"]).each_with_index.filter_map do |timestamp, index|
          close = data.dig("c", index).to_f
          next unless close.positive?

          {
            traded_on: Time.at(timestamp.to_i).utc.to_date,
            open_price: data.dig("o", index).to_f,
            high_price: data.dig("h", index).to_f,
            low_price: data.dig("l", index).to_f,
            close_price: close,
            volume: data.dig("v", index).to_i
          }
        end

        { success: true, bars: bars.sort_by { _1[:traded_on] }.uniq { _1[:traded_on] } }
      rescue JSON::ParserError
        { success: false, error: "Response was not JSON" }
      end
    end
  end
end
