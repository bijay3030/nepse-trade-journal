require "rails_helper"

RSpec.describe "Api::V1::Stocks", type: :request do
  let!(:user) { create(:user) }
  let!(:stock) { create(:stock, symbol: "NABIL", name: "Nabil Bank Limited") }
  let!(:daily_price) { create(:stock_daily_price, stock: stock, traded_on: Date.current, close_price: 520.0) }
  let!(:financial) { create(:stock_company_financial, stock: stock, fiscal_year: "2080/81", quarter: "Q4", eps: 25.5) }

  let(:secret) { "secret" }
  let(:auth_headers) do
    token = JWT.encode({ jti: user.jti, sub: user.id }, secret, "HS256")
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/stocks" do
    it "returns list of active stocks with fundamental metrics" do
      get "/api/v1/stocks", headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.first["symbol"]).to eq("NABIL")
      expect(json.first["eps"]).to eq(25.5)
    end
  end

  describe "GET /api/v1/stocks/:id/historical_prices" do
    it "returns historical price records for stock" do
      get "/api/v1/stocks/NABIL/historical_prices", headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).not_to be_empty
      expect(json.first["close_price"]).to eq(520.0)
    end
  end

  describe "GET /api/v1/stocks/:id/financials" do
    it "returns company financial records for stock" do
      get "/api/v1/stocks/NABIL/financials", headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.first["fiscal_year"]).to eq("2080/81")
      expect(json.first["quarter"]).to eq("Q4")
      expect(json.first["eps"]).to eq(25.5)
    end
  end
end
