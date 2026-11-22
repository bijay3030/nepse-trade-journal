require "httparty"
require "nokogiri"

module Nepse
  module Source
    # ShareSansar's Live Trading page: every security's last traded price during the
    # session, with the time the page was last updated ("As of", Nepal time) and whether
    # the market is open. Same columns as the summary page (SharesansarMarketClient), so
    # rows come out in the same shape, plus `as_of` and `market_open`.
    class SharesansarLiveClient < SharesansarMarketClient
      URL = "https://www.sharesansar.com/live-trading".freeze

      def fetch
        response = HTTParty.get(URL, headers: { "User-Agent" => USER_AGENT }, timeout: REQUEST_TIMEOUT)
        return { success: false, error: { code: :http_error, message: "HTTP #{response.code}" } } unless response.success?

        parse(response.body)
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        { success: false, error: { code: :request_failed, message: e.message } }
      end

      def parse(html, fetched_at: Time.current)
        doc = Nokogiri::HTML(html)
        as_of = Time.find_zone(MarketHours::TIME_ZONE).parse(doc.at_css("#dDate")&.text.to_s.squish) rescue nil
        # Without its own time stamp the page can't be dated, so it isn't used.
        return { success: false, error: { code: :no_timestamp, message: "Live page has no As of time" } } unless as_of

        result = super(html, traded_on: as_of&.to_date, fetched_at: fetched_at)
        return result unless result[:success]

        result.merge(as_of: as_of, market_open: doc.css("button").any? { _1.text.squish.casecmp("Market Open").zero? })
      end
    end
  end
end
