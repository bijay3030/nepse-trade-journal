require "rails_helper"

RSpec.describe Maintenance::DataRetention do
  let(:stock) { create(:stock) }
  let(:days) { (1..5).map { Date.new(2026, 9, 20) + _1 } }

  before do
    days.each do |day|
      StockSetupSnapshot.create!(stock: stock, traded_on: day, close_price: 100, zone_state: "no_setup")
      StockIntradayVolume.create!(stock: stock, traded_on: day, minute: 30, volume: 100)
    end
  end

  it "keeps the latest N sessions and recent intraday days when limits are set" do
    allow(Nepse::MarketHours).to receive(:today).and_return(Date.new(2026, 9, 26))

    result = described_class.call(env: { "RETAIN_SNAPSHOT_SESSIONS" => "2", "RETAIN_INTRADAY_DAYS" => "3" })

    expect(StockSetupSnapshot.pluck(:traded_on)).to contain_exactly(days[3], days[4])
    expect(StockIntradayVolume.pluck(:traded_on)).to contain_exactly(days[2], days[3], days[4])
    expect(result).to include(setup_snapshots: 3, intraday_volumes: 2, broker_flows: 0)
  end

  it "keeps everything when no limits are set" do
    described_class.call(env: {})

    expect(StockSetupSnapshot.count).to eq(5)
    expect(StockIntradayVolume.count).to eq(5)
  end
end
