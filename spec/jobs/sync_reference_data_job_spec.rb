require "rails_helper"

RSpec.describe SyncReferenceDataJob do
  it "runs the daily syncs and backfills history for new listings" do
    expect(Nepse::Reference::UniverseSync).to receive(:call).and_return({ success: true, created: [ "NEWCO" ] })
    expect(Nepse::HistoryBackfillService).to receive(:call).with(symbols: [ "NEWCO" ]).and_return({ success: true })
    expect(Indicators::BatchCalculatorService).to receive(:call).with(symbols: [ "NEWCO" ], recalculate_all: true)
    expect(Nepse::Reference::DividendSync).to receive(:call).and_return({ success: true })
    expect(CorporateActions::WatchlistUpdater).to receive(:call).and_return({ warned: 0, adjusted: 0 })
    expect(CorporateActions::HistoryRefresh).to receive(:call).and_return({ refreshed: [] })
    expect(Nepse::Reference::IndexHistorySync).to receive(:call).with(days: 14).and_return({ success: true })
    expect(Flows::BrokerSync).to receive(:call).and_return({ success: true, brokers: 92 })
    expect(Flows::Backfill).to receive(:call).with(sessions: 5).and_return({ success: true, imported: [], failed: {} })
    expect(Nepse::Reference::FundamentalsSync).not_to receive(:call)

    described_class.perform_now("daily")
  end

  it "runs fundamentals weekly" do
    expect(Nepse::Reference::FundamentalsSync).to receive(:call).and_return({ success: true })
    expect(Nepse::Reference::UniverseSync).not_to receive(:call)

    described_class.perform_now("weekly")
  end
end
