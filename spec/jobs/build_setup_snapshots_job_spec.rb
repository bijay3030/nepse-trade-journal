require "rails_helper"

RSpec.describe BuildSetupSnapshotsJob do
  include ActiveJob::TestHelper

  it "updates indicators before rebuilding snapshots, then queues the backtest and the daily digests" do
    expect(Indicators::BatchCalculatorService).to receive(:call).ordered.and_return({ processed_indicators: 10 })
    expect(Setups::SnapshotBuilder).to receive(:call).ordered.and_return({ success: true, stocks: 2, in_buy_zone: [] })

    expect { expect(described_class.perform_now).to include(success: true, stocks: 2) }
      .to have_enqueued_job(BacktestJob).and have_enqueued_job(BuildDailyDigestsJob).and have_enqueued_job(TelegramBoardJob)
  end

  it "skips the backtest and digests when no snapshots were built" do
    allow(Indicators::BatchCalculatorService).to receive(:call).and_return({})
    allow(Setups::SnapshotBuilder).to receive(:call).and_return({ success: false, error: "No stock prices stored" })
    expect { described_class.perform_now }.not_to have_enqueued_job(BacktestJob)
    expect { described_class.perform_now }.not_to have_enqueued_job(BuildDailyDigestsJob)
  end
end
