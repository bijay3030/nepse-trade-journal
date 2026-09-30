require "rails_helper"

RSpec.describe CorporateActions::HistoryRefresh do
  let(:today) { Date.new(2026, 10, 5) }
  let(:history) { class_double(Nepse::HistoryBackfillService) }
  let(:sbl) { create(:stock, symbol: "SBL") }
  let(:old) { create(:stock, symbol: "OLD") }

  before do
    sbl.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: today - 2, source: "chukul")
    old.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: today - 30, source: "chukul")
    create(:stock, symbol: "CASH").dividends.create!(fiscal_year: "082/083", cash_percent: 10, bonus_percent: 0, book_close_on: today - 2, source: "chukul")
    allow(Indicators::BatchCalculatorService).to receive(:call)
  end

  it "re-fetches adjusted history for recent bonus book closes, once" do
    expect(history).to receive(:call).with(symbols: [ "SBL" ]).once.and_return({ success: true, failed: {} })
    expect(Indicators::BatchCalculatorService).to receive(:call).with(symbols: [ "SBL" ], recalculate_all: true)

    expect(described_class.call(on: today, history: history)).to eq(refreshed: [ "SBL" ], failed: [])
    expect(sbl.dividends.sole.history_refreshed_at).to be_present
    expect(described_class.call(on: today, history: history)).to eq(refreshed: [])
  end

  it "retries next time when the download fails" do
    allow(history).to receive(:call).and_return({ success: true, failed: { "SBL" => "timeout" } })

    expect(described_class.call(on: today, history: history)).to eq(refreshed: [], failed: [ "SBL" ])
    expect(sbl.dividends.sole.history_refreshed_at).to be_nil
  end
end
