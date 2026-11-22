require "rails_helper"

RSpec.describe CorporateActions::HistoryRefresh do
  let(:today) { Date.new(2026, 10, 5) }
  let(:history) { class_double(Nepse::HistoryBackfillService) }
  let(:archive) { class_double(Scans::History, import!: { stocks: 1, rows: 10, failed: {} }) }
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

    expect(described_class.call(on: today, history: history, archive: archive)).to eq(refreshed: [ "SBL" ], failed: [])
    expect(sbl.dividends.sole.history_refreshed_at).to be_present
    expect(described_class.call(on: today, history: history, archive: archive)).to eq(refreshed: [])
  end

  it "also adjusts for a recent rights book close, and re-fetches the archive" do
    nica = create(:stock, symbol: "NICA")
    MarketEvent.create!(stock: nica, source: "chukul_rights", external_id: "NICA:083/84:50.0", kind: "rights", impact: "negative",
                        title: "NICA: 50% rights shares", published_on: today - 20, event_on: today - 1, data: { "right" => 50.0 })
    expect(history).to receive(:call).with(symbols: %w[SBL NICA]).and_return({ success: true, failed: {} })

    described_class.call(on: today, history: history, archive: archive)

    expect(archive).to have_received(:import!).with(symbols: %w[SBL NICA])
    expect(MarketEvent.sole.data).to include("history_refreshed_at")
    expect(described_class.call(on: today, history: history, archive: archive)).to eq(refreshed: [])
  end

  it "retries next time when the download fails" do
    allow(history).to receive(:call).and_return({ success: true, failed: { "SBL" => "timeout" } })

    expect(described_class.call(on: today, history: history, archive: archive)).to eq(refreshed: [], failed: [ "SBL" ])
    expect(sbl.dividends.sole.history_refreshed_at).to be_nil
  end
end
