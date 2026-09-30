require "rails_helper"

RSpec.describe BuildSetupSnapshotsJob do
  it "updates indicators before rebuilding snapshots" do
    expect(Indicators::BatchCalculatorService).to receive(:call).ordered.and_return({ processed_indicators: 10 })
    expect(Setups::SnapshotBuilder).to receive(:call).ordered.and_return({ success: true, stocks: 2, in_buy_zone: [] })

    expect(described_class.perform_now).to include(success: true, stocks: 2)
  end
end
