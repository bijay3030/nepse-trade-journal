require "rails_helper"

RSpec.describe Events::BookCloseStudy do
  let(:stock) { create(:stock, symbol: "BKCL", security_type: "Equity") }
  let(:start) { Date.new(2024, 1, 1) }

  before do
    # Rises 1 a session to the book close (session 40), then falls 0.5 a session.
    (0...80).each do |i|
      close = i <= 40 ? 100.0 + i : 140.0 - (i - 40) * 0.5
      create(:stock_daily_price, stock: stock, traded_on: start + i, close_price: close, previous_close: close)
    end
    stock.dividends.create!(fiscal_year: "080/081", bonus_percent: 15, cash_percent: 1, book_close_on: start + 40, source: "chukul")
  end

  it "measures the run-up before a book close and the move after it, by group" do
    result = described_class.call(rights_feed: { success: true, data: [] })

    expect(result[:events]).to eq(1)
    group = result[:groups].find { _1[:key] == "bonus_10" }
    expect(group).to include(count: 1, run_up_avg: ((139.0 / 119.0 - 1) * 100).round(2), run_up_up_pct: 100.0)
    expect(group[:after_avg]).to eq(((130.5 / 139.0 - 1) * 100).round(2)) # 20 sessions after the last close before it
    expect(result[:groups].find { _1[:key] == "rights" }).to eq({ key: "rights", label: "Rights issue", count: 0 })
  end
end
