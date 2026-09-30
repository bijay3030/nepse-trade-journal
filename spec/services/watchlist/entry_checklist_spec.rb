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
    expect(result).to include(passed: 8, total: 8, all_passed: true)
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
    expect(described_class.call(item, context: context)[:total]).to eq(7)
  end

  it "marks the sector check not applicable without a sector index" do
    stock.update!(sector: "Mutual Fund")

    expect(statuses["sector"]).to eq("n/a")
  end

  it "checks the pattern and treats a base breakout like a breakout" do
    item.update!(setup_type: "base_breakout")
    allow(Setups::Patterns).to receive(:base_breakout).and_return({ success: true, details: { base_sessions: 31, base_depth_pct: 8.0 } })

    checks = described_class.call(item, context: context)[:checks].index_by { _1[:key] }

    expect(checks["pattern"]).to include(label: "Flat base near the 52-week high", status: "pass", detail: "31-session base, 8.0% deep")
    expect(checks["close"][:label]).to eq("Closed above the pivot")
    expect(checks["volume"][:status]).to eq("pending")
  end

  it "treats an MA pullback like a pullback" do
    item.update!(setup_type: "ma_pullback")
    allow(Setups::Patterns).to receive(:ma_pullback).and_return({ success: false, error: "Not an uptrend above a rising 50-day average" })

    checks = described_class.call(item, context: context)[:checks].index_by { _1[:key] }

    expect(checks["pattern"]).to include(status: "fail", detail: "Not an uptrend above a rising 50-day average")
    expect(checks["close"][:label]).to eq("Closed inside the entry zone")
    expect(checks["volume"][:status]).to eq("n/a")
  end

  describe "book close rule" do
    let(:today) { Nepse::MarketHours.today }

    def book_close_check = described_class.call(item, context: context)[:checks].find { _1[:key] == "book_close" }

    it "fails when a bonus book close is within 10 days" do
      stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, cash_percent: 5, book_close_on: today + 4, source: "chukul")

      expect(book_close_check).to include(status: "fail", detail: "10.0% bonus, book close #{(today + 4).strftime('%b %-d')}")
    end

    it "passes a cash-only book close with a note, and a bonus further away" do
      stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 0, cash_percent: 12, book_close_on: today + 3, source: "chukul")
      expect(book_close_check).to include(status: "pass", detail: "Cash dividend only (12.0%), book close #{(today + 3).strftime('%b %-d')}")

      StockDividend.delete_all
      stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: today + 20, source: "chukul")
      expect(book_close_check).to include(status: "pass", detail: "None announced")
    end
  end
end
