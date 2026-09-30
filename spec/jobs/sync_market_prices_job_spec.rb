require "rails_helper"

RSpec.describe SyncMarketPricesJob do
  it "skips outside market hours" do
    allow(Nepse::MarketHours).to receive(:sync_window?).and_return(false)
    expect(Nepse::LivePriceSync).not_to receive(:call)

    expect(described_class.perform_now).to include(skipped: :market_closed)
  end

  it "syncs during market hours" do
    allow(Nepse::MarketHours).to receive(:sync_window?).and_return(true)
    expect(Nepse::LivePriceSync).to receive(:call).and_return({ success: true, processed: 3 })

    expect(described_class.perform_now).to include(success: true, processed: 3)
  end

  it "runs when forced even if the market is closed" do
    allow(Nepse::MarketHours).to receive(:sync_window?).and_return(false)
    expect(Nepse::LivePriceSync).to receive(:call).and_return({ success: true, processed: 3 })

    described_class.perform_now(true)
  end

  it "falls back to per-symbol prices when a forced sync fails" do
    allow(Nepse::LivePriceSync).to receive(:call).and_return({ success: false, error: "timeout" })
    expect(Nepse::DailyPriceImporterService).to receive(:call).and_return({ success: true, processed: 2 })
    expect(Nepse::LivePriceSync).to receive(:broadcast)

    expect(described_class.perform_now(true)).to include(success: true, processed: 2)
  end
end
