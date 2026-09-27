require "rails_helper"

RSpec.describe Nepse::MasterImporterService do
  describe ".call" do
    it "seeds stocks from default json dataset" do
      result = described_class.call
      expect(result[:success]).to be true
      expect(Stock.count).to be >= 10
      expect(Stock.find_by(symbol: "NABIL")).to be_present
    end
  end
end
