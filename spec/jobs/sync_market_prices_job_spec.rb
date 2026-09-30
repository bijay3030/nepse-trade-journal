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
    expect(Watchlist::CloseEvaluator).to receive(:call).and_return({ evaluated: 2, alerts: 1 })

    expect(described_class.perform_now(true)).to include(close: { evaluated: 2, alerts: 1 })
  end

  it "does not judge closes on the intraday runs" do
    allow(Nepse::MarketHours).to receive(:sync_window?).and_return(true)
    allow(Nepse::LivePriceSync).to receive(:call).and_return({ success: true, processed: 3 })
    expect(Watchlist::CloseEvaluator).not_to receive(:call)

    described_class.perform_now
  end

  it "falls back to per-symbol prices when a forced sync fails" do
    allow(Nepse::LivePriceSync).to receive(:call).and_return({ success: false, error: "timeout" })
    expect(Nepse::DailyPriceImporterService).to receive(:call).and_return({ success: true, processed: 2 })
    expect(Nepse::LivePriceSync).to receive(:publish)
    expect(Watchlist::CloseEvaluator).to receive(:call).and_return({ evaluated: 0, alerts: 0 })

    expect(described_class.perform_now(true)).to include(success: true, processed: 2)
  end
end
