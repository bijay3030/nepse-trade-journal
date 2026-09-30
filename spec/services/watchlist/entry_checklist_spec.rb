require "rails_helper"

RSpec.describe Watchlist::EntryChecklist do
  let(:stock) { create(:stock, symbol: "NABIL", sector: "Commercial Banks", last_price: 505.0) }
  # Zone 500-515, invalidation/stop 470, target 560 => 2R.
  let(:item) { create(:watchlist_item, stock: stock) }
  let(:context) { instance_double(Watchlist::MarketContext, regime: "neutral", nepse_return: -1.2, sector_returns: { "Commercial Banks" => 0.8 }) }
  let(:vcp) do
    { is_vcp_setup: true, setup_quality_score: 80, contraction_sequence_text: "13.4% -> 5.4%", classification: "contracting_price_and_volume",
      qualification_checks: [ { label: "Volume drying up", passed: true } ] }
  end

  before { allow(Vcp::DetectionEngine).to receive(:call).and_return(vcp) }

  def statuses = described_class.call(item, context: context)[:checks].to_h { [ _1[:key], _1[:status] ] }

  it "passes every check for a confirmed VCP breakout in a healthy market" do
    item.update!(last_close_on: Date.new(2026, 9, 30), last_close_state: "confirmed", last_close_price: 508, last_close_relative_volume: 1.8)

    result = described_class.call(item, context: context)

    expect(result[:checks].map { _1[:status] }).to all(eq("pass"))
    expect(result).to include(passed: 7, total: 7, all_passed: true)
    expect(result[:checks].find { _1[:key] == "sector" }[:detail]).to eq("Commercial Banks +0.80% vs NEPSE -1.20%")
  end

  it "leaves the close and volume pending until the first end-of-day check" do
    expect(statuses).to include("close" => "pending", "volume" => "pending")
    expect(described_class.call(item, context: context)[:all_passed]).to be(false)
  end

  it "explains which VCP rules are not met" do
    vcp.merge!(is_vcp_setup: false, qualification_checks: [ { label: "Volume drying up", passed: false }, { label: "Base at least 15 trading days", passed: false } ])

    pattern = described_class.call(item, context: context)[:checks].first
    expect(pattern).to include(status: "fail", detail: "Not met: Volume drying up; Base at least 15 trading days")
  end

  it "fails on a weak market, a lagging sector, poor risk:reward and a chased price" do
    weak = instance_double(Watchlist::MarketContext, regime: "weak", nepse_return: 2.0, sector_returns: { "Commercial Banks" => 0.5 })
    item.update!(target_price: 530) # 1R
    stock.update!(last_price: 520)

    result = described_class.call(item, context: weak)[:checks].to_h { [ _1[:key], _1[:status] ] }
    expect(result).to include("regime" => "fail", "sector" => "fail", "risk_reward" => "fail", "not_extended" => "fail")
  end

  it "uses trend instead of VCP rules for pullbacks and skips the volume check" do
    item.update!(setup_type: "pullback", last_close_on: Date.new(2026, 9, 30), last_close_state: "held_zone", last_close_price: 505)
    allow(PriceAction::AnalyzerService).to receive(:call).and_return({ trend: "uptrend", structure: "higher_high_higher_low" })

    expect(statuses).to include("pattern" => "pass", "close" => "pass", "volume" => "n/a")
    expect(described_class.call(item, context: context)[:total]).to eq(6)
  end

  it "marks the sector check not applicable without a sector index" do
    stock.update!(sector: "Mutual Fund")

    expect(statuses["sector"]).to eq("n/a")
  end
end
