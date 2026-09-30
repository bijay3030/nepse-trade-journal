require "rails_helper"

RSpec.describe Nepse::Source::MerolaganiHistoryClient do
  describe "#parse" do
    it "turns chart arrays into daily bars dated by the UTC session date" do
      body = {
        s: "ok",
        t: [ 1790196273, 1790282683 ], # 2026-09-23 and 2026-09-24, ~20:44 UTC
        o: [ 566.0, 566.0 ], h: [ 570.0, 570.0 ], l: [ 565.0, 566.0 ], c: [ 565.0, 569.0 ], v: [ 88_903.0, 70_749.0 ]
      }.to_json

      result = described_class.new.parse(body)

      expect(result[:success]).to be(true)
      expect(result[:bars]).to eq([
        { traded_on: Date.new(2026, 9, 23), open_price: 566.0, high_price: 570.0, low_price: 565.0, close_price: 565.0, volume: 88_903 },
        { traded_on: Date.new(2026, 9, 24), open_price: 566.0, high_price: 570.0, low_price: 566.0, close_price: 569.0, volume: 70_749 }
      ])
    end

    it "reports an error when the symbol has no data" do
      expect(described_class.new.parse({ s: "no_data" }.to_json)).to include(success: false)
      expect(described_class.new.parse("<html>")).to eq(success: false, error: "Response was not JSON")
    end
  end
end
