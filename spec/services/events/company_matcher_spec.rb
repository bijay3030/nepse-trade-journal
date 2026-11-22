require "rails_helper"

RSpec.describe Events::CompanyMatcher do
  before do
    create(:stock, symbol: "NABIL", name: "Nabil Bank Limited", security_type: "Equity")
    create(:stock, symbol: "SIKLES", name: "Sikles Hydropwer limited", security_type: "Equity")
    create(:stock, symbol: "NFS", name: "Nepal Finance Ltd.", security_type: "Equity")
    create(:stock, symbol: "MFLB", name: "Mahila Micro Finance Bittiya Sanstha Ltd.", security_type: "Equity")
    create(:stock, symbol: "NABILP", name: "Nabil Bank Limited Promoter", security_type: "Promoter Share")
  end

  let(:matcher) { described_class.new }
  let(:id) { ->(symbol) { Stock.find_by!(symbol: symbol).id } }

  it "matches the company the title names, tolerating spacing and small spelling differences" do
    expect(matcher.stock_id("Nabil Bank Limited has posted a net profit of Rs 1 billion")).to eq(id.("NABIL"))
    expect(matcher.stock_id("Sikles Hydropower Limited has announced its 22nd AGM")).to eq(id.("SIKLES"))
    expect(matcher.stock_id("Mahila Microfinance Bittiya Sanstha Limited has announced its AGM")).to eq(id.("MFLB"))
    expect(matcher.stock_id("The existing promoter of Nepal Finance Limited is selling 2,31,403 shares")).to eq(id.("NFS"))
  end

  it "leaves unlisted companies unmatched" do
    expect(matcher.stock_id("Nabil Investment Banking Limited has published a notice")).to be_nil
    expect(matcher.stock_id("Orbit Energy Limited has announced its 3rd AGM")).to be_nil
  end
end
