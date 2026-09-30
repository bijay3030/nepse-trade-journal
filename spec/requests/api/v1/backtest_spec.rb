require "rails_helper"

RSpec.describe "Backtest API", type: :request do
  it "returns the latest run" do
    BacktestRun.create!(from_date: Date.new(2026, 5, 11), to_date: Date.new(2026, 9, 28), sessions: 1, results: { old: true })
    BacktestRun.create!(from_date: Date.new(2026, 5, 11), to_date: Date.new(2026, 9, 28), sessions: 120, parameters: { max_hold: 20 }, results: { trades: { total: 12 } })

    get "/api/v1/backtest"

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include("sessions" => 120, "from_date" => "2026-05-11", "parameters" => { "max_hold" => 20 })
    expect(body["results"]).to eq("trades" => { "total" => 12 })
  end

  it "explains when no backtest has run" do
    get "/api/v1/backtest"

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)["error"]).to include("nepse:data:backtest")
  end
end
