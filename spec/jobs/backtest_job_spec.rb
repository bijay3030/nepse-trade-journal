require "rails_helper"

RSpec.describe BacktestJob do
  include ActiveJob::TestHelper

  it "runs the backtest, warms the indicator scan, then queues the scanner's Telegram messages" do
    expect(Backtest::Runner).to receive(:call).and_return({ success: true, run_id: 7 })
    expect(Scans::Cache).to receive(:crossovers).and_return({})

    expect { described_class.perform_now }.to have_enqueued_job(TelegramScannerJob)
  end
end
