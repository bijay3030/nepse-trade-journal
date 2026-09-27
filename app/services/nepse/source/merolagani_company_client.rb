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
        normalized_symbol = normalize_symbol(symbol)
        response = HTTParty.get(
          format(URL, symbol: CGI.escape(normalized_symbol)),
          headers: { "User-Agent" => USER_AGENT },
          timeout: REQUEST_TIMEOUT
        )
        return { success: false, symbol: normalized_symbol, error: { code: :http_error, message: "HTTP #{response.code}" } } unless response.success?

        parse(normalized_symbol, response.body)
      rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
        { success: false, symbol: normalized_symbol, error: { code: :request_failed, message: e.message } }
      end

      def parse(symbol, html)
        normalized_symbol = normalize_symbol(symbol)
        fields = extract_fields(Nokogiri::HTML(html))
        return missing_details_error(normalized_symbol) if fields.empty?

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
            fiscal_year: "latest",
            quarter: "Annual"
          }
        }
      end

      private

      def normalize_symbol(symbol)
        symbol.to_s.upcase.strip
      end

      def extract_fields(doc)
        doc.css("tr").each_with_object({}) do |row, fields|
          cells = row.css("th, td")
          next if cells.length < 2

          key = normalize_label(cells[0].text)
          next if key.blank?

          fields[key] ||= cells[1].text.to_s.strip
        end.slice(*recognized_labels)
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

      def cleaned_number(value)
        text = value.to_s.delete(",").delete("% ").strip
        return if text.blank? || text == "-"
        return unless text.match?(/\A-?\d+(?:\.\d+)?\z/)

        text
      end
    end
  end
end
