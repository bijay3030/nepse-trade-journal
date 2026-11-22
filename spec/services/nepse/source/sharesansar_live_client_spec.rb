require "rails_helper"

RSpec.describe Nepse::Source::SharesansarLiveClient do
  let(:html) { file_fixture("sharesansar_live_trading.html").read }

  it "reads every row with the page's own time and whether the market is open" do
    result = described_class.new.parse(html)

    expect(result).to include(success: true, market_open: true)
    expect(result[:as_of]).to eq(Time.find_zone("Asia/Kathmandu").parse("2026-11-23 12:40:00"))
    expect(result[:rows].map { _1.slice(:symbol, :last_price, :previous_close, :change_percent, :volume, :traded_on) }).to eq([
      { symbol: "NABIL", last_price: 550.5, previous_close: 549.0, change_percent: 0.27, volume: 12_345, traded_on: Date.new(2026, 11, 23) },
      { symbol: "NICA", last_price: 420.0, previous_close: 425.0, change_percent: -1.18, volume: 5_000, traded_on: Date.new(2026, 11, 23) }
    ])
  end

  it "refuses a page without its time stamp" do
    expect(described_class.new.parse(html.sub(/<span id="dDate".*?<\/span>/, ""))).to include(success: false)
  end
end
