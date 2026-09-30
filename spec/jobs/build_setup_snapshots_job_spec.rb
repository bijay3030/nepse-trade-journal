require "rails_helper"

RSpec.describe BuildSetupSnapshotsJob do
  include ActiveJob::TestHelper

  it "updates indicators before rebuilding snapshots, then queues the daily digests" do
    expect(Indicators::BatchCalculatorService).to receive(:call).ordered.and_return({ processed_indicators: 10 })
    expect(Setups::SnapshotBuilder).to receive(:call).ordered.and_return({ success: true, stocks: 2, in_buy_zone: [] })
    expect(Backtest::Runner).to receive(:call).ordered.and_return({ success: true, run_id: 1 })

    expect { expect(described_class.perform_now).to include(success: true, stocks: 2) }.to have_enqueued_job(BuildDailyDigestsJob)
  end

  it "skips the backtest and digests when no snapshots were built" do
    allow(Indicators::BatchCalculatorService).to receive(:call).and_return({})
    allow(Setups::SnapshotBuilder).to receive(:call).and_return({ success: false, error: "No stock prices stored" })
    expect(Backtest::Runner).not_to receive(:call)

    expect { described_class.perform_now }.not_to have_enqueued_job(BuildDailyDigestsJob)
  end
end
