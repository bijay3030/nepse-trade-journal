require "rails_helper"

RSpec.describe "Daily digests", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }

  before do
    allow(MarketIndex::Overview).to receive(:new).and_return(
      instance_double(MarketIndex::Overview, call: { traded_on: "2026-09-29", nepse_index: 2600.0, index_change_pct: 0.5, regime_status: "neutral",
                                                     advancing_stocks: 1, declining_stocks: 0, unchanged_stocks: 0, market_breadth_pct: 100, sectors: [] })
    )
    StockSetupSnapshot.create!(stock: create(:stock), traded_on: Date.new(2026, 9, 29), close_price: 100, zone_state: "too_early")
  end

  it "builds the latest digest on demand, lists it and marks it read" do
    get "/api/v1/digests/latest", headers: headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include("traded_on" => "2026-09-29", "read_at" => nil, "headline" => "NEPSE +0.50%")
    expect(body["content"]["market"]).to include("regime" => "neutral")

    get "/api/v1/digests", headers: headers
    expect(JSON.parse(response.body)).to include("unread_count" => 1)

    post "/api/v1/digests/2026-09-29/mark_read", headers: headers
    expect(JSON.parse(response.body)["read_at"]).to be_present
    get "/api/v1/digests", headers: headers
    expect(JSON.parse(response.body)["unread_count"]).to eq(0)
  end

  it "saves the digest preferences and doesn't build a digest when it is off" do
    patch "/api/v1/digest_preferences", params: { enabled: false, sections: %w[market watchlist bogus] }, headers: headers, as: :json
    expect(JSON.parse(response.body)).to include("enabled" => false, "sections" => %w[market watchlist])

    get "/api/v1/digests/latest", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "keeps digests private to their user" do
    Digests::Builder.call(create(:user))

    get "/api/v1/digests/2026-09-29", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
