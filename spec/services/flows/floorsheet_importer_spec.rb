require "rails_helper"

RSpec.describe Flows::FloorsheetImporter do
  let(:day) { Date.new(2026, 9, 28) }
  let(:client) { instance_double(Nepse::Source::ChukulClient) }
  let!(:nabil) { create(:stock, symbol: "NABIL") }
  let(:trades) do
    [
      { "symbol" => "NABIL", "buyer" => "58", "seller" => "33", "quantity" => 100.0, "rate" => 570.0, "amount" => 57_000.0 },
      { "symbol" => "NABIL", "buyer" => "58", "seller" => "45", "quantity" => 50.0, "rate" => 568.0, "amount" => 28_400.0 },
      { "symbol" => "NABIL", "buyer" => "33", "seller" => "58", "quantity" => 20.0, "rate" => 569.0, "amount" => 11_380.0 },
      { "symbol" => "UNLISTED", "buyer" => "1", "seller" => "2", "quantity" => 10.0, "rate" => 100.0, "amount" => 1_000.0 }
    ]
  end

  before { allow(client).to receive(:floorsheet).with(day).and_return({ success: true, data: trades }) }

  it "rolls trades up per stock and broker" do
    result = described_class.call(day, client: client)

    expect(result).to include(success: true, trades: 4, rows: 3, symbols: 1)
    flow = StockBrokerFlow.find_by!(stock: nabil, traded_on: day, broker_no: "58")
    expect(flow).to have_attributes(buy_quantity: 150, sell_quantity: 20, trades: 3, net_quantity: 130)
    expect(flow.buy_amount.to_f).to eq(85_400.0)
    expect(StockBrokerFlow.where(stock: nabil, traded_on: day).sum(:buy_quantity)).to eq(170)
  end

  it "replaces the day when run again" do
    described_class.call(day, client: client)
    described_class.call(day, client: client)

    expect(StockBrokerFlow.where(traded_on: day).count).to eq(3)
  end

  it "reports a missing or empty floorsheet" do
    allow(client).to receive(:floorsheet).and_return({ success: true, data: [] })
    expect(described_class.call(day, client: client)).to include(success: false, error: "No trades (market closed?)")

    allow(client).to receive(:floorsheet).and_return({ success: false, error: "HTTP 500" })
    expect(described_class.call(day, client: client)).to include(success: false, error: "HTTP 500")
  end
end
