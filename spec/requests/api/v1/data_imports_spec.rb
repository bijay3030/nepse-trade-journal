require "rails_helper"

RSpec.describe "Api::V1::DataImports", type: :request do
  let!(:user) { create(:user) }
  let!(:stock) { create(:stock, symbol: "NABIL", last_updated: Time.zone.parse("2026-09-27 09:00")) }
  let(:auth_headers) do
    token = JWT.encode({ jti: user.jti, sub: user.id }, "secret", "HS256")
    { "Authorization" => "Bearer #{token}" }
  end

  describe "POST /api/v1/data_imports/sync_market" do
    it "syncs the market table and reports the result" do
      allow(Nepse::LivePriceSync).to receive(:call)
        .and_return({ success: true, processed: 356, created_symbols: [ "NEWCO" ], rejected_symbols: [] })

      post "/api/v1/data_imports/sync_market", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include("processed" => 356, "added" => [ "NEWCO" ])
      expect(Time.zone.parse(json["last_updated"])).to eq(Time.zone.parse("2026-09-27 09:00"))
    end

    it "returns a readable error when the source is unavailable" do
      allow(Nepse::LivePriceSync).to receive(:call)
        .and_return({ success: false, error: { code: :http_error, message: "HTTP 503" } })

      post "/api/v1/data_imports/sync_market", headers: auth_headers

      expect(response).to have_http_status(:bad_gateway)
      expect(JSON.parse(response.body)["error"]).to eq("Could not fetch market prices: HTTP 503")
    end

    it "says so when the prices aren't fresh, without changing anything" do
      allow(Nepse::LivePriceSync).to receive(:call)
        .and_return({ success: false, stale: true, reasons: { sharesansar_live: "last updated 11:40", sharesansar_summary: "prices are for 2026-11-20, not today" } })

      post "/api/v1/data_imports/sync_market", headers: auth_headers

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)["error"]).to eq("Prices aren't fresh: last updated 11:40; prices are for 2026-11-20, not today. Nothing was changed.")
    end
  end
end
