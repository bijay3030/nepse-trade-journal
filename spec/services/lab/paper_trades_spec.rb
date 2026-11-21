require "rails_helper"

RSpec.describe Lab::PaperTrades do
  let(:stock) { create(:stock, symbol: "LABX", security_type: "Equity") }
  let(:candidate) do
    { stock_id: stock.id, strategy: "range_grid", signal_on: Date.new(2026, 11, 20),
      levels: { entry_low: 100.0, entry_high: 102.0, stop: 95.0, target: 110.0 }, record: { trades: 12, profit_factor: 1.6 } }
  end

  it "records a candidate once and follows it to its exit" do
    trade = described_class.record(candidate)
    expect(described_class.record(candidate)).to eq(trade)
    expect(trade).to have_attributes(status: "pending", levels: include(stop: 95.0))

    described_class.apply(trade, { status: :open, entry_on: Date.new(2026, 11, 23), entry: 101.0, exit: 104.0, return_pct: 2.97, r: 0.5 })
    expect(trade.reload).to have_attributes(status: "open", entry_price: 101.0)
    described_class.apply(trade, { status: :closed, entry_on: Date.new(2026, 11, 23), entry: 101.0, exit_on: Date.new(2026, 11, 30), exit: 110.0,
                                   reason: "target", return_pct: 8.11, r: 1.5 })
    expect(LabPaperTrade.active).to be_empty

    overview = described_class.overview
    expect(overview[:summary]).to include(total: 1, closed: 1, win_rate_pct: 100.0, avg_return_pct: 8.11)
    expect(overview[:trades].sole).to include(symbol: "LABX", status: "closed", exit_reason: "target")
  end

  it "keeps the reason when the entry was skipped" do
    trade = described_class.record(candidate)
    described_class.apply(trade, { status: :skipped, reason: "gap above the entry range", entry_index: 5 })
    expect(trade.reload).to have_attributes(status: "skipped", exit_reason: "gap above the entry range")
  end
end
