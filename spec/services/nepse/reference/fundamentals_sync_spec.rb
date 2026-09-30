require "rails_helper"

RSpec.describe Nepse::Reference::FundamentalsSync do
  let(:chukul) { instance_double(Nepse::Source::ChukulClient) }
  let(:merolagani) { instance_double(Nepse::Source::MerolaganiCompanyClient) }
  let!(:stock) { create(:stock, symbol: "NABIL", chukul_sector_id: 1, listed_shares: 0, last_price: 569.0, high_52w: 0, low_52w: 0) }
  let(:chukul_details) do
    { "fiscal_year" => "082/083", "quarter" => "q4", "eps_a" => 28.36, "pe_ratio" => 20.06, "pb_ratio" => 2.3, "net_worth" => 247.28,
      "net_profit" => 7_905_796_000.0, "paidup_capital" => 32_056_997_000.0, "roe" => 11.76, "roa" => 1.15, "dps" => nil,
      "core_capital" => 27_056_997_000.0, "fifty_two_max_close" => 569.0, "fifty_two_min_close" => 487.0 }
  end
  let(:merolagani_details) do
    { success: true, fundamentals: { listed_shares: 270_569_970, eps: 28.36, pe_ratio: 19.99, book_value: 247.28, pb_ratio: 2.29, fiscal_year: "082/083", quarter: "Q4" },
      high_52w: 581.0, low_52w: 485.0, cash_dividends: [], bonus_shares: [] }
  end

  before do
    allow(chukul).to receive(:stock_details).and_return({ success: true, data: chukul_details })
    allow(merolagani).to receive(:details).and_return(merolagani_details)
  end

  def run = described_class.call(symbols: [ "NABIL" ], chukul: chukul, merolagani: merolagani, delay_seconds: 0)

  it "takes fundamentals from Chukul and fills only the gaps from Merolagani" do
    merolagani_details[:fundamentals][:book_value] = 999.0
    chukul_details["dps"] = -54.95

    expect(run).to include(stocks: 1, from_chukul: 1, from_merolagani: 1)

    row = stock.company_financials.find_by!(fiscal_year: "082/083", quarter: "Q4")
    expect(row).to have_attributes(eps: 28.36, pe_ratio: 20.06, book_value: 247.28, roe: 11.76, roa: 1.15, reported_on: Date.current)
    expect(row.net_profit.to_f).to eq(7_905_796_000.0)
    expect(row.field_sources.dig("eps", "source")).to eq("chukul")
    # Chukul's "dps" is distributable profit per share, which can be negative.
    expect(row.distributable_profit_per_share.to_f).to eq(-54.95)
  end

  it "takes shares outstanding and the 52-week range from Merolagani and recalculates market cap" do
    run

    expect(stock.reload).to have_attributes(listed_shares: 270_569_970, high_52w: 581.0, low_52w: 485.0)
    expect(stock.market_cap.to_f).to eq(270_569_970 * 569.0)
    expect(stock.field_sources.dig("listed_shares", "source")).to eq("merolagani")
  end

  it "falls back to Chukul core capital when Merolagani is unavailable" do
    allow(merolagani).to receive(:details).and_return({ success: false, error: { message: "timeout" } })

    run

    expect(stock.reload.listed_shares).to eq(270_569_970)
    expect(stock.field_sources.dig("listed_shares", "source")).to eq("chukul")
    expect(stock.high_52w.to_f).to eq(569.0)
  end

  it "uses Merolagani's period when Chukul has no fundamentals, and removes undated placeholder rows" do
    allow(chukul).to receive(:stock_details).and_return({ success: false, error: "HTTP 500" })
    stock.company_financials.create!(fiscal_year: "latest", quarter: "Annual", eps: 0)

    expect(run).to include(from_chukul: 0, from_merolagani: 1)

    expect(stock.company_financials.pluck(:fiscal_year, :quarter)).to eq([ [ "082/083", "Q4" ] ])
    expect(stock.company_financials.first.eps.to_f).to eq(28.36)
  end

  it "reports securities no source could describe" do
    allow(chukul).to receive(:stock_details).and_return({ success: false, error: "HTTP 500" })
    allow(merolagani).to receive(:details).and_return({ success: false })

    expect(run[:failed]).to eq("NABIL" => "no fundamentals from any source")
  end

  it "does not store an empty row when no source has values for the period" do
    allow(chukul).to receive(:stock_details).and_return({ success: false, error: "HTTP 500" })
    merolagani_details[:fundamentals].merge!(eps: 0.0, pe_ratio: nil, book_value: nil, pb_ratio: nil, fiscal_year: "083/084")

    run

    expect(stock.company_financials).to be_empty
    expect(stock.reload.listed_shares).to eq(270_569_970)
  end

  it "skips promoter shares and debentures" do
    stock.update!(security_type: "Promoter Share")
    expect(chukul).not_to receive(:stock_details)

    expect(run).to include(stocks: 0)
  end
end
