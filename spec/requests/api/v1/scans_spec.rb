require "rails_helper"

RSpec.describe "Indicator scans", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }

  it "returns the scan with its parameters and the signals' backtest" do
    stock = create(:stock, symbol: "RISE", security_type: "Equity")
    (1..90).each { |i| create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 6, 1) + i, close_price: 100 + i) }

    get "/api/v1/scans/crossovers", headers: headers

    body = response.parsed_body
    expect(body["params"]).to include("hma" => 21, "aroon" => 25)
    expect(body["rows"].sole["symbol"]).to eq("RISE")
    expect(body["backtest"]["signals"].keys).to include("all", "ema_9_21", "aroon_strong")
    expect(body["backtest"]["signals"]["all"]["5"]["n"]).to be_positive
  end

  it "returns one stock's chart, and an error without enough history" do
    stock = create(:stock, symbol: "RISE", security_type: "Equity")
    (1..90).each { |i| create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 6, 1) + i, close_price: 100 + i) }
    create(:stock, symbol: "NEWLY")

    get "/api/v1/scans/crossovers/rise", headers: headers
    expect(response.parsed_body).to include("symbol" => "RISE")
    expect(response.parsed_body["candles"].size).to eq(90)

    get "/api/v1/scans/crossovers/NEWLY", headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
