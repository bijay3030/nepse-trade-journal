require "rails_helper"

RSpec.describe Nepse::Source::MerolaganiCompanyClient do
  describe "#parse" do
    it "parses valid fundamentals from a company detail response" do
      html = <<~HTML
        <html>
          <body>
            <table>
              <tr><td>Sector</td><td>Commercial Banks</td></tr>
              <tr><td>Listed Shares</td><td>100,000,000</td></tr>
              <tr><td>Market Capitalization</td><td>34,500,000,000</td></tr>
              <tr><td>EPS</td><td>24.50</td></tr>
              <tr><td>P/E Ratio</td><td>14.08</td></tr>
              <tr><td>Book Value</td><td>210.25</td></tr>
              <tr><td>PBV</td><td>1.64</td></tr>
            </table>
          </body>
        </html>
      HTML

      result = described_class.new.parse("adbl", html)

      expect(result).to eq(
        success: true,
        symbol: "ADBL",
        fundamentals: {
          sector: "Commercial Banks",
          listed_shares: 100_000_000,
          market_cap: 34_500_000_000.0,
          eps: 24.5,
          pe_ratio: 14.08,
          book_value: 210.25,
          pb_ratio: 1.64,
          fiscal_year: "latest",
          quarter: "Annual"
        }
      )
    end

    it "returns partial data without blowing away absent fields" do
      html = <<~HTML
        <html>
          <body>
            <table>
              <tr><td>Sector</td><td>Hydropower</td></tr>
              <tr><td>Listed Shares</td><td>12,345,678</td></tr>
              <tr><td>EPS</td><td>-</td></tr>
            </table>
          </body>
        </html>
      HTML

      result = described_class.new.parse("chcl", html)

      expect(result).to eq(
        success: true,
        symbol: "CHCL",
        fundamentals: {
          sector: "Hydropower",
          listed_shares: 12_345_678,
          market_cap: nil,
          eps: nil,
          pe_ratio: nil,
          book_value: nil,
          pb_ratio: nil,
          fiscal_year: "latest",
          quarter: "Annual"
        }
      )
    end

    it "falls back to alternate labels when preferred fields are blank" do
      html = <<~HTML
        <html>
          <body>
            <table>
              <tr><td>Listed Shares</td><td>-</td></tr>
              <tr><td>Shares Outstanding</td><td>98,765,432</td></tr>
              <tr><td>PBV</td><td></td></tr>
              <tr><td>PB Ratio</td><td>2.10</td></tr>
            </table>
          </body>
        </html>
      HTML

      result = described_class.new.parse("nica", html)

      expect(result).to eq(
        success: true,
        symbol: "NICA",
        fundamentals: {
          sector: nil,
          listed_shares: 98_765_432,
          market_cap: nil,
          eps: nil,
          pe_ratio: nil,
          book_value: nil,
          pb_ratio: 2.1,
          fiscal_year: "latest",
          quarter: "Annual"
        }
      )
    end

    it "returns a structured error when the page shape is missing" do
      result = described_class.new.parse("nabil", "<html><body><p>No company details</p></body></html>")

      expect(result).to eq(
        success: false,
        symbol: "NABIL",
        error: {
          code: :details_missing,
          message: "Merolagani company details not found"
        }
      )
    end
  end

  describe "#fetch" do
    it "fetches the per-symbol company detail page" do
      response = instance_double(HTTParty::Response, success?: true, body: <<~HTML)
        <table>
          <tr><td>Sector</td><td>Commercial Banks</td></tr>
        </table>
      HTML

      allow(HTTParty).to receive(:get).and_return(response)

      result = described_class.new.fetch("adbl")

      expect(HTTParty).to have_received(:get).with(
        "https://merolagani.com/CompanyDetail.aspx?symbol=ADBL",
        headers: { "User-Agent" => described_class::USER_AGENT },
        timeout: described_class::REQUEST_TIMEOUT
      )

      expect(result).to eq(
        success: true,
        symbol: "ADBL",
        fundamentals: {
          sector: "Commercial Banks",
          listed_shares: nil,
          market_cap: nil,
          eps: nil,
          pe_ratio: nil,
          book_value: nil,
          pb_ratio: nil,
          fiscal_year: "latest",
          quarter: "Annual"
        }
      )
    end

    it "returns a structured error for non-2xx responses" do
      response = instance_double(HTTParty::Response, success?: false, code: 404)
      allow(HTTParty).to receive(:get).and_return(response)

      result = described_class.new.fetch("adbl")

      expect(result).to eq(
        success: false,
        symbol: "ADBL",
        error: {
          code: :http_error,
          message: "HTTP 404"
        }
      )
    end

    it "returns a structured error for request failures" do
      allow(HTTParty).to receive(:get).and_raise(SocketError, "getaddrinfo failed")

      result = described_class.new.fetch("adbl")

      expect(result).to eq(
        success: false,
        symbol: "ADBL",
        error: {
          code: :request_failed,
          message: "getaddrinfo failed"
        }
      )
    end

    it "returns the structured parse error when the response body has no company details" do
      response = instance_double(HTTParty::Response, success?: true, body: "<html><body><p>broken</p></body></html>")
      allow(HTTParty).to receive(:get).and_return(response)

      result = described_class.new.fetch("adbl")

      expect(result).to eq(
        success: false,
        symbol: "ADBL",
        error: {
          code: :details_missing,
          message: "Merolagani company details not found"
        }
      )
    end
  end
end
