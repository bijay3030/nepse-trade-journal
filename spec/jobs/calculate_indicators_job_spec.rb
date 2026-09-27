require "rails_helper"

RSpec.describe CalculateIndicatorsJob, type: :job do
  describe "#perform" do
    it "invokes Indicators::BatchCalculatorService with expected arguments" do
      expect(Indicators::BatchCalculatorService).to receive(:call).with(
        symbols: ["NABIL"],
        batch_size: 10,
        recalculate_all: false
      ).and_return(success: true, processed_stocks: 1)

      result = described_class.new.perform(["NABIL"], 10, false)

      expect(result[:success]).to be true
      expect(result[:processed_stocks]).to eq(1)
    end
  end
end
