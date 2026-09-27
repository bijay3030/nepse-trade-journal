require "rails_helper"

RSpec.describe Nepse::Source::SharesansarMarketClient do
  describe "#parse" do
    it "parses one valid Sharesansar row into normalized attributes" do
      fetched_at = Time.zone.parse("2026-07-27 10:30:00")
      traded_on = Date.new(2026, 7, 27)

      html = <<~HTML
        <table>
          <thead>
            <tr>
              <th>S.N.</th>
              <th>Symbol</th>
              <th>Open</th>
              <th>High</th>
              <th>Low</th>
              <th>LTP</th>
              <th>% Change</th>
              <th>Qty.</th>
              <th>Turnover</th>
              <th>Prev. Close</th>
              <th>Diff</th>
              <th>No. of Transactions</th>
              <th>52 Weeks High</th>
              <th>52 Weeks Low</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>1</td>
              <td>adbl</td>
              <td>304.00</td>
              <td>329.00</td>
              <td>304.00</td>
              <td>322.00</td>
              <td>0.62%</td>
              <td>84,053</td>
              <td>27,182,336.20</td>
              <td>320.00</td>
              <td>2.00</td>
              <td>317</td>
              <td>344.90</td>
              <td>285.20</td>
            </tr>
          </tbody>
        </table>
      HTML

      result = described_class.new.parse(html, traded_on: traded_on, fetched_at: fetched_at)

      expect(result).to eq(
        success: true,
        rows: [
          {
            symbol: "ADBL",
            open_price: 304.0,
            high_price: 329.0,
            low_price: 304.0,
            close_price: 322.0,
            last_price: 322.0,
            previous_close: 320.0,
            change_amount: 2.0,
            change_percent: 0.62,
            volume: 84_053,
            turnover: 27_182_336.20,
            total_trades: 317,
            high_52w: 344.9,
            low_52w: 285.2,
            traded_on: traded_on,
            fetched_at: fetched_at
          }
        ]
      )
    end

    it "reads volume, percent change and transactions from the current Sharesansar headers" do
      html = <<~HTML
        <table>
          <thead>
            <tr>
              <th>S.No</th><th>Symbol</th><th>Conf.</th><th>Open</th><th>High</th><th>Low</th><th>Close</th>
              <th>LTP</th><th>Close - LTP</th><th>Close - LTP %</th><th>VWAP</th><th>Vol</th><th>Prev. Close</th>
              <th>Turnover</th><th>Trans.</th><th>Diff</th><th>Range</th><th>Diff %</th>
              <th>52 Weeks High</th><th>52 Weeks Low</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>1</td><td>ACLBSL</td><td>37.39</td><td>871.10</td><td>890.00</td><td>871.10</td><td>877.00</td>
              <td>877.00</td><td>0.00</td><td>0.00</td><td>886.95</td><td>281.00</td><td>878.00</td>
              <td>249,233.50</td><td>13</td><td>-1.00</td><td>18.90</td><td>-0.11</td>
              <td>1,095.00</td><td>827.90</td>
            </tr>
          </tbody>
        </table>
      HTML

      row = described_class.new.parse(html)[:rows].first

      expect(row).to include(
        symbol: "ACLBSL",
        last_price: 877.0,
        previous_close: 878.0,
        change_amount: -1.0,
        change_percent: -0.11,
        volume: 281,
        total_trades: 13,
        turnover: 249_233.5
      )
    end

    it "rejects rows without a usable symbol or last price" do
      html = <<~HTML
        <table>
          <thead>
            <tr>
              <th>Symbol</th>
              <th>LTP</th>
              <th>Open</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td></td>
              <td>500.00</td>
              <td>490.00</td>
            </tr>
            <tr>
              <td>NABIL</td>
              <td>-</td>
              <td>490.00</td>
            </tr>
          </tbody>
        </table>
      HTML

      result = described_class.new.parse(html)

      expect(result).to eq(success: true, rows: [])
    end

    it "returns a structured error when the table is missing" do
      result = described_class.new.parse("<html><body><p>No data</p></body></html>")

      expect(result).to eq(
        success: false,
        error: {
          code: :table_missing,
          message: "Sharesansar market table not found"
        }
      )
    end

    it "does not derive change_percent from a raw change column" do
      html = <<~HTML
        <table>
          <thead>
            <tr>
              <th>Symbol</th>
              <th>LTP</th>
              <th>Change</th>
              <th>Diff</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>NABIL</td>
              <td>500.00</td>
              <td>5.00</td>
              <td>5.00</td>
            </tr>
          </tbody>
        </table>
      HTML

      result = described_class.new.parse(html)

      expect(result[:success]).to be(true)
      expect(result[:rows]).to contain_exactly(
        include(
          symbol: "NABIL",
          last_price: 500.0,
          change_amount: 5.0,
          change_percent: nil
        )
      )
    end
  end

  describe "#fetch" do
    it "returns parse errors without masking them as request failures" do
      response = instance_double(HTTParty::Response, success?: true, body: "<html><body>broken</body></html>")
      allow(HTTParty).to receive(:get).and_return(response)

      result = described_class.new.fetch

      expect(result).to eq(
        success: false,
        error: {
          code: :table_missing,
          message: "Sharesansar market table not found"
        }
      )
    end
  end
end
