require "rails_helper"

RSpec.describe Scans::MarketPhase do
  describe ".trend" do
    it "compares the 20-session average with the 50-session one, with a 1% band" do
      expect(described_class.trend([ 100.0 ] * 30 + [ 110.0 ] * 20)).to eq("uptrend")
      expect(described_class.trend([ 100.0 ] * 30 + [ 90.0 ] * 20)).to eq("downtrend")
      expect(described_class.trend([ 100.0 ] * 30 + [ 101.0 ] * 20)).to eq("sideways") # +0.6% vs the 50-session average
      expect(described_class.trend([ 100.0 ] * 10)).to eq("sideways")
    end
  end

  context "with archived and regular NEPSE closes" do
    let(:nepse) { create(:market_index, symbol: "NEPSE") }
    let(:start) { Date.new(2025, 1, 1) }

    before do
      60.times { |i| MarketIndexArchive.create!(market_index: nepse, traded_on: start + i, index_value: 100) }
      MarketIndexArchive.create!(market_index: nepse, traded_on: start + 60, index_value: 1) # overlaps the regular history: ignored
      25.times { |i| create(:market_index_history, market_index: nepse, traded_on: start + 60 + i, index_value: 120) }
    end

    it "joins the archive before the regular history" do
      points = described_class.series
      expect(points.size).to eq(85)
      expect(points[59..60]).to eq([ [ start + 59, 100.0 ], [ start + 60, 120.0 ] ])
    end

    it "gives a phase for every session with 50 closes behind it" do
      timeline = described_class.timeline
      expect(timeline.keys.first).to eq(start + 49)
      expect(timeline[start + 59]).to eq("sideways")
      expect(timeline[start + 84]).to eq("uptrend")
    end

    it "reports today's phase and how long it has lasted" do
      current = described_class.current(as_of: start + 84)
      expect(current).to include(phase: "uptrend", as_of: start + 84, sma20: 120.0, band_pct: 1.0)
      expect(current[:sessions]).to be_between(20, 25)
      expect(described_class.current(as_of: start + 59)).to include(phase: "sideways")
    end

    it "imports NEPSE closes from 2020 up to the regular history" do
      MarketIndexArchive.delete_all
      client = instance_double(Nepse::Source::MerolaganiHistoryClient)
      allow(client).to receive(:fetch).with("NEPSE", from: Date.new(2020, 1, 1), to: start + 59).and_return(
        success: true, bars: [ { traded_on: Date.new(2020, 1, 2), close_price: 1200.5 }, { traded_on: start + 60, close_price: 999 } ]
      )

      expect(described_class.import!(client: client)).to eq(1)
      expect(MarketIndexArchive.pluck(:traded_on, :index_value).map { [ _1, _2.to_f ] }).to eq([ [ Date.new(2020, 1, 2), 1200.5 ] ])
    end
  end
end
