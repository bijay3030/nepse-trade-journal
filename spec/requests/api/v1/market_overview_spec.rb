require "rails_helper"

RSpec.describe "Market overview", type: :request do
  it "returns an empty snapshot without an observed NEPSE session" do
    get "/api/v1/market/overview"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("traded_on" => nil, "index_history" => [], "sectors" => [])
  end

  it "derives breadth and sector turnover from the index session's stock prices" do
    index = create(:market_index, symbol: "NEPSE")
    create(:market_index_history, market_index: index, traded_on: Date.new(2026, 9, 18), index_value: 2650, turnover: 9000)
    create(:market_index_history, market_index: index, traded_on: Date.new(2026, 9, 17), index_value: 2600)
    bank = create(:stock, symbol: "BANK", sector: "Commercial Banks")
    hydro = create(:stock, symbol: "HYDRO", sector: "Hydropower")
    create(:stock_daily_price, stock: bank, traded_on: Date.new(2026, 9, 18), close_price: 105, previous_close: 100, turnover: 600, volume: 10)
    create(:stock_daily_price, stock: hydro, traded_on: Date.new(2026, 9, 18), close_price: 95, previous_close: 100, turnover: 400, volume: 10)
    create(:stock_daily_price, stock: bank, traded_on: Date.new(2026, 9, 17), close_price: 100)

    get "/api/v1/market/overview"
    body = JSON.parse(response.body)
    expect(body).to include("traded_on" => "2026-09-18", "nepse_index" => 2650.0, "market_turnover" => 9000.0,
                            "advancing_stocks" => 1, "declining_stocks" => 1, "total_stocks_audited" => 2)
    expect(body.fetch("index_history").map { |point| point.fetch("value") }).to eq([2600.0, 2650.0])
    expect(body.fetch("sectors").find { |sector| sector["sector"] == "Commercial Banks" }).to include("sector_turnover" => 600.0, "advancing_stocks" => 1)
  end

  it "does not label unknown breadth weak when only index history exists" do
    index = create(:market_index, symbol: "NEPSE")
    create(:market_index_history, market_index: index, traded_on: Date.new(2026, 9, 18))
    get "/api/v1/market/overview"
    expect(JSON.parse(response.body)).to include("breadth_rating" => "neutral", "regime_status" => "neutral")
  end
end
