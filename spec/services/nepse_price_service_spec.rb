require "rails_helper"

RSpec.describe NepsePriceService do
  def stub_response(body)
    response = instance_double(HTTParty::Response, success?: true, body: body.to_json)
    allow(HTTParty).to receive(:get).and_return(response)
  end

  it "leaves fields the API does not provide as nil instead of zero" do
    stub_response({ id: "NABIL", symbol: "NABIL", company_name: "Nabil Bank Limited", ltp: 569 })

    quote = described_class.new("NABIL").fetch_current

    expect(quote).to include(symbol: "NABIL", last_price: 569.0, change_percent: nil, volume: nil, total_trades: nil)
  end

  it "keeps values the API does provide" do
    stub_response({ symbol: "NABIL", ltp: 569, percentageChange: 1.2, volume: 5000, totalTrades: 40 })

    quote = described_class.new("NABIL").fetch_current

    expect(quote).to include(change_percent: 1.2, volume: 5000, total_trades: 40)
  end
end
