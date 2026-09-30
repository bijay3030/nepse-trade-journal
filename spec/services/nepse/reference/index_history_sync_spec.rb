require "rails_helper"

RSpec.describe Nepse::Reference::IndexHistorySync do
  let(:chukul) { instance_double(Nepse::Source::ChukulClient) }
  let(:merolagani) { instance_double(Nepse::Source::MerolaganiHistoryClient) }

  before do
    allow(chukul).to receive(:history).and_return({ success: false, error: "No history" })
    allow(merolagani).to receive(:fetch).and_return({ success: false })
    allow(chukul).to receive(:history).with("NEPSE", anything).and_return({ success: true, bars: [
      { traded_on: Date.new(2026, 9, 23), close: 2590.0, turnover: 4.0e9 },
      { traded_on: Date.new(2026, 9, 28), close: 2607.92, turnover: 5.1e9 }
    ] })
    allow(merolagani).to receive(:fetch).with("NEPSE", anything).and_return({ success: true, bars: [
      { traded_on: Date.new(2026, 9, 24), close_price: 2600.0 },
      { traded_on: Date.new(2026, 9, 28), close_price: 9999.0 }
    ] })
  end

  it "stores Chukul's sessions, fills gaps from Merolagani and computes changes" do
    result = described_class.call(days: 30, chukul: chukul, merolagani: merolagani, to: Date.new(2026, 9, 28))

    expect(result[:indices]["NEPSE"]).to eq(sessions: 3, from_merolagani: 1, latest: Date.new(2026, 9, 28))
    index = MarketIndex.find_by!(symbol: "NEPSE")
    expect(index).to have_attributes(name: "NEPSE Index", current_value: 2607.92, source: "chukul")
    values = index.histories.chronological.pluck(:traded_on, :index_value, :change_point).map { |d, v, c| [ d.day, v.to_f, c.to_f ] }
    expect(values).to eq([ [ 23, 2590.0, 0.0 ], [ 24, 2600.0, 10.0 ], [ 28, 2607.92, 7.92 ] ])
    expect(result[:failed]).to include("BANKINGIND")
  end

  it "links sector indices to their sector" do
    allow(chukul).to receive(:history).with("BANKINGIND", anything).and_return({ success: true, bars: [ { traded_on: Date.new(2026, 9, 28), close: 1400.0, turnover: 0 } ] })

    described_class.call(days: 30, chukul: chukul, merolagani: merolagani, to: Date.new(2026, 9, 28))

    expect(MarketIndex.find_by!(symbol: "BANKINGIND")).to have_attributes(name: "Commercial Banks Index", sector: "Commercial Banks")
  end
end
