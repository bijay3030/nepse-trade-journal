require "rails_helper"

RSpec.describe "Positions", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }
  let(:stock) { create(:stock, symbol: "NABIL", last_price: 520) }
  let!(:item) { create(:watchlist_item, user: user, stock: stock) }

  def json = JSON.parse(response.body)

  it "records a buy from a watchlist item and lists the position with live figures" do
    post "/api/v1/positions", params: { watchlist_item_id: item.id, price: 505, quantity: 100, traded_on: "2026-10-01" }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(json).to include("symbol" => "NABIL", "status" => "open", "quantity" => 100, "average_price" => 505.0, "last_price" => 520.0,
                            "stop_price" => 470.0, "target_price" => 560.0, "unrealized_pnl" => 1500.0, "r_multiple" => 0.43,
                            "opened_on" => "2026-10-01", "sellable_on" => "2026-10-05")
    expect(json["fills"].sole).to include("side" => "buy", "price" => 505.0, "quantity" => 100)

    get "/api/v1/watchlist_items", headers: headers
    expect(json.sole).to include("status" => "holding", "position_id" => user.positions.sole.id)

    get "/api/v1/positions", headers: headers
    expect(json.map { _1["symbol"] }).to eq([ "NABIL" ])
  end

  it "records a buy by symbol, edits the plan, and removes a fill" do
    post "/api/v1/positions", params: { symbol: "nabil", price: 500, quantity: 50 }, headers: headers, as: :json
    id = json["id"]

    patch "/api/v1/positions/#{id}", params: { stop_price: 480, target_price: 600, notes: "Breakout on volume" }, headers: headers, as: :json
    expect(json).to include("stop_price" => 480.0, "target_price" => 600.0, "notes" => "Breakout on volume", "initial_stop_price" => 470.0)

    patch "/api/v1/positions/#{id}", params: { stop_price: -1 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    delete "/api/v1/positions/#{id}/fills/#{Position.find(id).fills.first.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(item.reload.status).not_to eq("holding")
  end

  it "rejects a bad quantity and keeps positions private" do
    post "/api/v1/positions", params: { watchlist_item_id: item.id, price: 505, quantity: 0 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["error"]).to match(/Quantity/)

    other = create(:user).positions.create!(stock: stock, stop_price: 470, initial_stop_price: 470)
    get "/api/v1/positions/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "returns portfolio heat and sector exposure" do
    user.update!(trading_capital: 1_000_000)
    post "/api/v1/positions", params: { watchlist_item_id: item.id, price: 505, quantity: 100, traded_on: "2026-10-01" }, headers: headers, as: :json

    get "/api/v1/positions/portfolio", headers: headers

    body = response.parsed_body
    expect(body["heat"]).to include("limit_pct" => 6.0, "state" => "ok")
    expect(body["sectors"].sole).to include("symbols" => [ stock.symbol ])
    expect(body["positions"].sole).to include("symbol" => stock.symbol, "share_of_risk_pct" => 100.0)
  end

  describe "closing and reviewing" do
    let(:position) do
      post "/api/v1/positions", params: { watchlist_item_id: item.id, price: 500, quantity: 100, traded_on: "2026-09-24" }, headers: headers, as: :json
      user.positions.sole
    end

    it "sells, closes with realized results, takes a review and reports stats" do
      post "/api/v1/positions/#{position.id}/sell", params: { price: 560, quantity: 100, traded_on: "2026-10-01" }, headers: headers, as: :json

      body = response.parsed_body
      expect(body).to include("status" => "closed", "warning" => nil, "average_sell_price" => 560.0)
      expect(body["realized"]["tax"]).to be_within(0.01).of(body["realized"]["gain"] * 0.1)

      patch "/api/v1/positions/#{position.id}/review", params: { review_plan_followed: "partly", review_tags: [ "sold_too_early" ], review_lesson: "Let it run" },
                                                     headers: headers, as: :json
      expect(response.parsed_body["review"]).to include("plan_followed" => "partly", "tags" => [ "sold_too_early" ], "lesson" => "Let it run")

      get "/api/v1/positions/stats", headers: headers
      expect(response.parsed_body).to include("closed" => 1, "win_rate_pct" => 100.0, "reviewed" => 1, "plan_followed_pct" => 0.0)
    end

    it "rejects an oversized sell and unknown review tags" do
      post "/api/v1/positions/#{position.id}/sell", params: { price: 560, quantity: 500 }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      patch "/api/v1/positions/#{position.id}/review", params: { review_tags: [ "lucky" ] }, headers: headers, as: :json
      expect(response.parsed_body["error"]).to include("unknown tags: lucky")
    end
  end
end
