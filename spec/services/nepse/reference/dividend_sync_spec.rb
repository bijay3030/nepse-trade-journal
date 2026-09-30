require "rails_helper"

RSpec.describe Nepse::Reference::DividendSync do
  let(:chukul) { instance_double(Nepse::Source::ChukulClient) }
  let(:merolagani) { instance_double(Nepse::Source::MerolaganiCompanyClient) }
  let!(:stock) { create(:stock, symbol: "NABIL") }

  def run = described_class.call(chukul: chukul, merolagani: merolagani, delay_seconds: 0)

  it "stores Chukul's dividend history with its dates" do
    allow(chukul).to receive(:dividends).and_return({ success: true, data: [
      { "year" => "082/083", "bonus" => 5.0, "cash" => 10.8, "total" => 15.8, "annoucement_date" => "2026-09-07", "book_close_date" => "2026-09-30", "agm_date" => "2026-10-08" },
      { "year" => "081/082", "bonus" => 0.0, "cash" => 12.5, "total" => 12.5, "annoucement_date" => "2025-12-07", "book_close_date" => "2025-12-31", "agm_date" => nil }
    ] })
    expect(merolagani).not_to receive(:details)

    expect(run).to include(stocks: 1, rows: 2)
    latest = stock.dividends.latest_first.first
    expect(latest).to have_attributes(fiscal_year: "082/083", cash_percent: 10.8, bonus_percent: 5.0, book_close_on: Date.new(2026, 9, 30), agm_on: Date.new(2026, 10, 8), source: "chukul")
  end

  it "falls back to Merolagani and merges cash and bonus by fiscal year" do
    allow(chukul).to receive(:dividends).and_return({ success: true, data: [] })
    allow(merolagani).to receive(:details).and_return({ success: true, cash_dividends: [ { fiscal_year: "082/083", percent: 10.8 } ], bonus_shares: [ { fiscal_year: "082/083", percent: 5.0 }, { fiscal_year: "080/081", percent: 3.0 } ] })

    expect(run).to include(from_merolagani: 1, rows: 2)
    expect(stock.dividends.find_by!(fiscal_year: "082/083")).to have_attributes(cash_percent: 10.8, bonus_percent: 5.0, total_percent: 15.8, source: "merolagani")
    expect(stock.dividends.find_by!(fiscal_year: "080/081").cash_percent).to be_nil
  end

  it "updates an existing year instead of duplicating it" do
    allow(chukul).to receive(:dividends).and_return({ success: true, data: [ { "year" => "082/083", "cash" => 10.0, "bonus" => 0, "total" => 10.0 } ] })
    run
    allow(chukul).to receive(:dividends).and_return({ success: true, data: [ { "year" => "082/083", "cash" => 10.8, "bonus" => 5, "total" => 15.8 } ] })
    run

    expect(stock.dividends.count).to eq(1)
    expect(stock.dividends.first.total_percent.to_f).to eq(15.8)
  end
end
