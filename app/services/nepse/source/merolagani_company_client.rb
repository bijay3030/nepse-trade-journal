require "cgi"
require "httparty"
require "nokogiri"

module Nepse
  module Source
    class MerolaganiCompanyClient
      URL = "https://merolagani.com/CompanyDetail.aspx?symbol=%{symbol}".freeze
      REQUEST_TIMEOUT = 10
      USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".freeze

      def fetch(symbol)
        with_page(symbol) { |normalized_symbol, html| parse(normalized_symbol, html) }
      end

      # Fundamentals plus the cash dividend and bonus history and the 52-week range.
      def details(symbol)
        with_page(symbol) { |normalized_symbol, html| parse_details(normalized_symbol, html) }
      end

      def parse_details(symbol, html)
        result = parse(symbol, html)
        return result unless result[:success]

        doc = Nokogiri::HTML(html)
        high, low = extract_fields(doc, %w[52weekshighlow]).values.first.to_s.delete(",").scan(/\d+(?:\.\d+)?/).map(&:to_f)
        latest = extract_fields(doc, %w[dividend bonus])
        result.merge(
          high_52w: high,
          low_52w: low,
          cash_dividends: with_latest(percent_history(doc.at_css("#dividend-panel")), latest["dividend"]),
          bonus_shares: with_latest(percent_history(doc.at_css("#bonus-panel")), latest["bonus"])
        )
      end

      def parse(symbol, html)
        normalized_symbol = normalize_symbol(symbol)
        fields = extract_fields(Nokogiri::HTML(html))
        return missing_details_error(normalized_symbol) if fields.empty?

        # EPS reads like "28.36 (FY:082-083, Q:4)".
        eps_period = fields["eps"].to_s.match(/FY:\s*(\d{3})-(\d{3})(?:,\s*Q:\s*(\d))?/)

        {
          success: true,
          symbol: normalized_symbol,
          fundamentals: {
            sector: text_value(fields["sector"]),
            listed_shares: first_integer_value(fields["listedshares"], fields["sharesoutstanding"]),
            market_cap: numeric_value(fields["marketcapitalization"]),
            eps: numeric_value(fields["eps"]),
            pe_ratio: numeric_value(fields["peratio"]),
            book_value: numeric_value(fields["bookvalue"]),
            pb_ratio: first_numeric_value(fields["pbv"], fields["pbratio"]),
            fiscal_year: eps_period ? "#{eps_period[1]}/#{eps_period[2]}" : "latest",
            quarter: eps_period&.[](3) ? "Q#{eps_period[3]}" : "Annual"
          }
        }
      end

      private

      def with_page(symbol)
        normalized_symbol = normalize_symbol(symbol)
        response = HTTParty.get(
          format(URL, symbol: CGI.escape(normalized_symbol)),
          headers: { "User-Agent" => USER_AGENT },
          timeout: REQUEST_TIMEOUT
        )
        return { success: false, symbol: normalized_symbol, error: { code: :http_error, message: "HTTP #{response.code}" } } unless response.success?

        yield normalized_symbol, response.body
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        { success: false, symbol: normalized_symbol, error: { code: :request_failed, message: e.message } }
      end

      # The summary row ("5.00 (FY:082-083)") sometimes has a value the history panel lacks.
      def with_latest(history, summary)
        year = summary.to_s.match(/FY:\s*(\d{3})-(\d{3})/)
        value = numeric_value(summary)
        return history unless year && value

        fiscal_year = "#{year[1]}/#{year[2]}"
        history.any? { _1[:fiscal_year] == fiscal_year } ? history : [ { fiscal_year: fiscal_year, percent: value } ] + history
      end

      # Rows like ["1.", "10.80%", "(FY: 082-083)"], in either column order.
      def percent_history(panel)
        return [] unless panel

        panel.css("tr").filter_map do |row|
          text = row.text.gsub(/\s+/, " ")
          year = text.match(/FY:\s*(\d{3})-(\d{3})/)
          value = text.match(/(-?\d+(?:\.\d+)?)\s*%/)
          { fiscal_year: "#{year[1]}/#{year[2]}", percent: value[1].to_f } if year && value
        end.uniq { _1[:fiscal_year] }
      end

      def normalize_symbol(symbol)
        symbol.to_s.upcase.strip
      end

      def extract_fields(doc, labels = recognized_labels)
        doc.css("tr").each_with_object({}) do |row, fields|
          cells = row.css("th, td")
          next if cells.length < 2

          key = normalize_label(cells[0].text)
          next if key.blank?

          fields[key] ||= cells[1].text.to_s.strip
        end.slice(*labels)
      end

      def recognized_labels
        %w[sector listedshares sharesoutstanding marketcapitalization eps peratio bookvalue pbv pbratio]
      end

      def missing_details_error(symbol)
        {
          success: false,
          symbol: symbol,
          error: {
            code: :details_missing,
            message: "Merolagani company details not found"
          }
        }
      end

      def normalize_label(text)
        text.to_s.downcase.gsub(/[^a-z0-9]/, "")
      end

      def text_value(value)
        text = value.to_s.strip
        return if text.blank? || text == "-"

        text
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

      def first_numeric_value(*values)
        values.each do |value|
          parsed = numeric_value(value)
          return parsed unless parsed.nil?
        end

        nil
      end

      def first_integer_value(*values)
        values.each do |value|
          parsed = integer_value(value)
          return parsed unless parsed.nil?
        end

        nil
      end

      # Reads the leading number, ignoring a trailing note such as "(FY:082-083, Q:4)".
      def cleaned_number(value)
        text = value.to_s.sub(/\(.*\z/m, "").delete(",").delete("% ").strip
        return if text.blank? || text == "-"
        return unless text.match?(/\A-?\d+(?:\.\d+)?\z/)

        text
      end
    end
  end
end
