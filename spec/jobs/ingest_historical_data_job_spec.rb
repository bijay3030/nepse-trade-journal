require "rails_helper"

RSpec.describe IngestHistoricalDataJob, type: :job do
  describe "#perform" do
    it "invokes Nepse::HistoricalDataIngestionService with parsed dates and options" do
      expect(Nepse::HistoricalDataIngestionService).to receive(:call).with(
        start_date: Date.parse("2026-01-01"),
        end_date: Date.parse("2026-06-30"),
        symbols: ["NABIL"],
        batch_size: 10,
        provider: :historical
      ).and_return(success: true, processed_stocks: 1)

      result = described_class.new.perform("2026-01-01", "2026-06-30", ["NABIL"], 10, :historical)

      expect(result[:success]).to be true
      expect(result[:processed_stocks]).to eq(1)
    end
  end
end
