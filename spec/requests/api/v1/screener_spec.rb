require "rails_helper"

RSpec.describe "VCP screener", type: :request do
  let!(:stock) { create(:stock, symbol: "NABIL") }

  before do
    30.times do |day|
      close = 100 + day * 0.5
      create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 8, 1) + day,
             close_price: close, high_price: close + 3, low_price: close - 3,
             previous_close: close - 0.5, volume: 10_000 - day * 100)
    end
  end

  it "does not fabricate a VCP pivot for a monotonic price series" do
    get "/api/v1/screener"
    expect(response).to have_http_status(:ok)
    row = JSON.parse(response.body).fetch("results").sole
    expect(row).to include("symbol" => "NABIL", "sector" => "Commercial Banks", "trend_state" => "sideways")
    expect(row.fetch("pivot")).to be_nil
    expect(row.fetch("vcp_score")).to eq(0)
    expect(%w[watch near_pivot breakout failed_breakout invalidated]).to include(row.fetch("setup_state"))
  end

  it "returns chart candles, levels, contraction and score components for a stock" do
    get "/api/v1/screener/NABIL"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.fetch("candles").size).to eq(30)
    expect(body.fetch("vcp")).to include("pivot_level" => nil, "classification" => "no_pattern")
    expect(body.fetch("vcp_breakdown").size).to eq(5)
    expect(body.fetch("price_action")).to include("support_levels" => be_an(Array), "resistance_levels" => be_an(Array))
  end

  it "returns 404 for an unknown symbol" do
    get "/api/v1/screener/UNKNOWN"
    expect(response).to have_http_status(:not_found)
  end

  it "does not invent pivot or score for a stock without prices" do
    create(:stock, symbol: "EMPTY")
    get "/api/v1/screener"
    expect(JSON.parse(response.body).fetch("results").map { |row| row.fetch("symbol") }).not_to include("EMPTY")
  end

  it "uses the latest active equity session instead of a newer inactive security" do
    inactive = create(:stock, symbol: "INACTIVE", is_active: false)
    create(:stock_daily_price, stock: inactive, traded_on: Date.new(2026, 9, 20))
    get "/api/v1/screener"
    body = JSON.parse(response.body)
    expect(body.fetch("traded_on")).to eq("2026-08-30")
    expect(body.fetch("results").map { |row| row.fetch("symbol") }).to eq(["NABIL"])
  end

  it "uses the existing VCP detection engine's observed pivot and score for a contracting series" do
    candidate = create(:stock, symbol: "VCP")
    highs = [180, 185, 192, 198, 200, 192, 184, 172, 164, 172, 180, 186, 189, 190,
             184, 178, 172, 171, 176, 181, 184, 185, 182, 178, 176, 179, 182, 184]
    highs.each_with_index do |high, day|
      low = high - (day < 10 ? 8 : day < 20 ? 5 : 3)
      create(:stock_daily_price, stock: candidate, traded_on: Date.new(2026, 8, 3) + day,
             high_price: high, low_price: low, close_price: (high + low) / 2.0,
             volume: (30 - day) * 1000)
    end

    expected = Vcp::DetectionEngine.call(candidate.daily_prices.to_a)
    get "/api/v1/screener/VCP"
    detail = JSON.parse(response.body)
    expect(detail.fetch("vcp")).to include("pivot_level" => expected[:pivot_level],
                                            "setup_quality_score" => expected[:setup_quality_score],
                                            "contractions_count" => expected[:contractions_count])
    expect(detail.fetch("vcp_breakdown").sum { |component| component.fetch("score") }).to eq(expected[:setup_quality_score])
  end
end
