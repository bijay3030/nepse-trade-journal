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

  describe "#parse_details" do
    let(:html) do
      <<~HTML
        <table id="accordion">
          <tr><th>Sector</th><td>Commercial Banks</td></tr>
          <tr><th>Shares Outstanding</th><td>270,569,970.00</td></tr>
          <tr><th>52 Weeks High - Low</th><td>581.00-485.00</td></tr>
          <tr><th>EPS</th><td>28.36 <span>(FY:082-083, Q:4)</span></td></tr>
          <tr><th>% Dividend</th><td>10.80 <span>(FY:082-083)</span></td></tr>
          <tr><th>% Bonus</th><td>5.00 <span>(FY:082-083)</span></td></tr>
        </table>
        <div id="dividend-panel"><table>
          <tr><th>#</th><th>Fiscal Year</th><th>Value</th></tr>
          <tr><td>1.</td><td>10.80%</td><td>(FY: 082-083)</td></tr>
          <tr><td>2.</td><td>12.50%</td><td>(FY: 081-082)</td></tr>
        </table></div>
        <div id="bonus-panel"><table><tr><th>#</th><th>Value</th><th>Fiscal Year</th></tr></table></div>
      HTML
    end

    it "reads EPS with its period, the 52-week range and dividend history" do
      result = described_class.new.parse_details("nabil", html)

      expect(result[:fundamentals]).to include(eps: 28.36, fiscal_year: "082/083", quarter: "Q4", listed_shares: 270_569_970)
      expect(result).to include(high_52w: 581.0, low_52w: 485.0)
      expect(result[:cash_dividends]).to eq([ { fiscal_year: "082/083", percent: 10.8 }, { fiscal_year: "081/082", percent: 12.5 } ])
      # The bonus panel is empty, so the summary row supplies the latest bonus.
      expect(result[:bonus_shares]).to eq([ { fiscal_year: "082/083", percent: 5.0 } ])
    end
  end
end
