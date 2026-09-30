require "rails_helper"

RSpec.describe Flows::Backfill do
  let(:client) { instance_double(Nepse::Source::ChukulClient) }
  let(:index) { create(:market_index, symbol: "NEPSE") }

  before do
    [ 24, 25, 28 ].each { create(:market_index_history, market_index: index, traded_on: Date.new(2026, 9, _1)) }
    StockBrokerFlow.create!(stock: create(:stock), traded_on: Date.new(2026, 9, 24), broker_no: "1")
  end

  it "imports only index sessions not stored yet, oldest first" do
    expect(Flows::FloorsheetImporter).to receive(:call).with(Date.new(2026, 9, 25), client: client).ordered.and_return({ success: true })
    expect(Flows::FloorsheetImporter).to receive(:call).with(Date.new(2026, 9, 28), client: client).ordered.and_return({ success: false, error: "HTTP 500" })

    result = described_class.call(sessions: 10, client: client, delay_seconds: 0)

    expect(result).to include(imported: [ Date.new(2026, 9, 25) ], failed: { Date.new(2026, 9, 28) => "HTTP 500" })
  end
end
