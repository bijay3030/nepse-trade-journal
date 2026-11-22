require "httparty"
require "nokogiri"

module Nepse
  module Source
    # ShareSansar's company announcement list, newest first, ten to a page. Older pages
    # come from the "Next" link's cursor. Each item has a title (which starts with the
    # company's name), a link and the day it was published.
    class SharesansarAnnouncementsClient
      URL = "https://www.sharesansar.com/announcement".freeze
      REQUEST_TIMEOUT = 30
      USER_AGENT = SharesansarMarketClient::USER_AGENT

      # { success:, items: [{ title:, url:, published_on: }], next_cursor: }
      def page(cursor: nil)
        response = HTTParty.get(URL, query: cursor ? { cursor: cursor } : {},
                                     headers: { "User-Agent" => USER_AGENT, "X-Requested-With" => "XMLHttpRequest" }, timeout: REQUEST_TIMEOUT)
        return { success: false, error: "HTTP #{response.code}" } unless response.success?

        parse(response.body)
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        { success: false, error: e.message }
      end

      def parse(html)
        doc = Nokogiri::HTML(html)
        items = doc.css(".featured-news-list").filter_map do |node|
          link = node.at_css("a[href*='announcementdetail/']")
          title = node.at_css(".featured-announcement-title")&.text.to_s.squish
          next if link.nil? || title.empty?

          url = link["href"]
          date_text = node.at_css(".text-org")&.text.to_s.squish
          published = (Date.parse(date_text) rescue nil) || (Date.parse(url[/(\d{4}-\d{2}-\d{2})\z/, 1]) rescue nil)
          next unless published

          { title: title, url: url, published_on: published }
        end
        next_href = doc.at_css("a[rel='next']")&.[]("href").to_s
        { success: true, items: items.uniq { _1[:url] }, next_cursor: next_href[/cursor=([^&]+)/, 1] }
      end
    end
  end
end
