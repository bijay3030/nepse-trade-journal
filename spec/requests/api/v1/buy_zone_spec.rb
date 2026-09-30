require "rails_helper"

RSpec.describe "Buy zone and snapshot-backed screener", type: :request do
  let(:day) { Date.new(2026, 9, 28) }
  let!(:bank) { create(:stock, symbol: "BANK", name: "Bank Ltd", sector: "Commercial Banks") }
  let!(:hydro) { create(:stock, symbol: "HYDRO", sector: "Hydropower") }

  before do
    allow(MarketIndex::Overview).to receive(:new).and_return(instance_double(MarketIndex::Overview, call: { regime_status: "neutral" }))
    create(:stock_daily_price, stock: bank, traded_on: day)
    StockSetupSnapshot.create!(stock: bank, traded_on: day, close_price: 200, zone_state: "in_zone", in_buy_zone: true, readiness_score: 72,
                               trend_rules_passed: 6, rs_rating: 88, setup_type: "vcp", entry_zone_low: 195, entry_zone_high: 205,
                               invalidation_price: 180, trend_checks: [ { key: "rs_rating", passed: true } ],
                               readiness_components: { trend: { points: 31, max: 35 } }, screener_row: { symbol: "BANK", sector: "Commercial Banks", vcp_score: 80 })
    StockSetupSnapshot.create!(stock: hydro, traded_on: day, close_price: 100, zone_state: "too_early", readiness_score: 20,
                               screener_row: { symbol: "HYDRO", sector: "Hydropower", vcp_score: 10 })
  end

  it "lists stocks in their buy zone, ranked by readiness, with the criteria" do
    get "/api/v1/screener/buy_zone"

    body = JSON.parse(response.body)
    expect(body).to include("traded_on" => "2026-09-28", "criteria" => { "zone_state" => "in_zone", "min_trend_rules" => 5, "min_readiness" => 60, "min_avg_turnover" => 2_000_000.0, "circuit_near_pct" => 9.5 }, "held_back" => [])
    expect(body["results"].map { _1["symbol"] }).to eq([ "BANK" ])
    expect(body["results"].first).to include("name" => "Bank Ltd", "readiness_score" => 72, "rs_rating" => 88, "entry_zone_low" => 195.0)
    expect(body["results"].first["readiness_history"]).to eq([ { "traded_on" => "2026-09-28", "score" => 72, "zone_state" => "in_zone", "in_buy_zone" => true } ])
  end

  it "lists every stock when asked" do
    get "/api/v1/screener/buy_zone", params: { all: true }

    expect(JSON.parse(response.body)["results"].map { _1["symbol"] }).to eq(%w[BANK HYDRO])
  end

  it "serves screener rows from the snapshots with readiness fields" do
    expect(Stock::SetupAnalysis).not_to receive(:new)

    get "/api/v1/screener"

    body = JSON.parse(response.body)
    expect(body["traded_on"]).to eq("2026-09-28")
    expect(body["results"].first).to include("symbol" => "BANK", "vcp_score" => 80, "readiness_score" => 72, "zone_state" => "in_zone", "in_buy_zone" => true)
  end
end
