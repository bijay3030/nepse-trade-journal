require "rails_helper"

RSpec.describe IngestMarketDataJob, type: :job do
  let(:date) { Date.parse("2026-09-20") }

  describe "#perform" do
    it "invokes Nepse::MarketDataIngestionService with target date and provider" do
      expect(Nepse::MarketDataIngestionService).to receive(:call)
        .with(date, provider: :yonepse)
        .and_return(success: true, processed_count: 5)

      result = described_class.new.perform("2026-09-20", :yonepse)

      expect(result[:success]).to be true
      expect(result[:processed_count]).to eq(5)
    end
  end
end
