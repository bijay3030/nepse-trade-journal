require "rails_helper"

RSpec.describe Nepse::Reference::UniverseSync do
  let(:client) { instance_double(Nepse::Source::ChukulClient) }
  let(:companies) do
    [
      { "id" => 2, "symbol" => "NABIL", "name" => "Nabil Bank Limited", "sector" => 1, "is_delisted" => false, "is_merged" => false },
      { "id" => 90, "symbol" => "BANDIPUR", "name" => "Bandipur Cable Car and Tourism Limited", "sector" => 4, "is_delisted" => false, "is_merged" => false },
      { "id" => 500, "symbol" => "SEF2", "name" => "Siddhartha Equity Fund 2", "sector" => 13, "is_delisted" => false, "is_merged" => false },
      { "id" => 7, "symbol" => "OLDBANK", "name" => "Old Bank", "sector" => 1, "is_delisted" => false, "is_merged" => true },
      { "id" => 8, "symbol" => "GONE", "name" => "Gone Ltd", "sector" => 5, "is_delisted" => true, "is_merged" => false },
      { "id" => 9, "symbol" => "ODD", "name" => "Odd", "sector" => 99, "is_delisted" => false, "is_merged" => false }
    ]
  end

  before { allow(client).to receive(:companies).and_return({ success: true, data: companies }) }

  it "adds, corrects and deactivates securities with their source recorded" do
    create(:stock, symbol: "BANDIPUR", name: "BANDIPUR Company", sector: "s")
    create(:stock, symbol: "OLDBANK", name: "Old Bank")
    stray = create(:stock, symbol: "LOCAL1", sector: "Development Bank Limited", security_type: "Equity")

    result = described_class.call(client: client)

    expect(result).to include(success: true, created: %w[NABIL SEF2], deactivated: [ "OLDBANK" ], skipped: [ "ODD" ])
    expect(Stock.find_by!(symbol: "BANDIPUR")).to have_attributes(name: "Bandipur Cable Car and Tourism Limited", sector: "Hotels And Tourism", chukul_id: 90, chukul_sector_id: 4)
    expect(Stock.find_by!(symbol: "SEF2")).to have_attributes(sector: "Mutual Fund", security_type: "Mutual Fund", is_active: true)
    expect(Stock.find_by!(symbol: "OLDBANK").is_active).to be(false)
    expect(Stock.exists?(symbol: "GONE")).to be(false)
    expect(Stock.find_by!(symbol: "NABIL").field_sources["sector"]).to include("source" => "chukul")
    expect(stray.reload.sector).to eq("Development Banks")
  end

  it "reports a failed company list without changing anything" do
    allow(client).to receive(:companies).and_return({ success: false, error: "HTTP 503" })

    expect(described_class.call(client: client)).to eq(success: false, error: "Chukul company list: HTTP 503")
    expect(Stock.count).to eq(0)
  end
end
