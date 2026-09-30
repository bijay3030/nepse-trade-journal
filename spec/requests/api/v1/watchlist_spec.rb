require "rails_helper"

RSpec.describe "Api::V1::Watchlist", type: :request do
  let!(:user) { create(:user) }
  let!(:stock) { create(:stock, symbol: "NABIL", last_price: 560.0) }
  let(:headers) do
    { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" }
  end
  let(:suggestion) do
    {
      success: true, setup_type: "vcp",
      levels: { entry_zone_low: 570.0, entry_zone_high: 587.1, invalidation_price: 548.0, stop_loss_price: 548.0,
                target_price: 640.0, target_basis: "resistance", pivot_price: 570.0 },
      snapshot: { vcp_score: 72, market_regime: "bullish", analysed_on: "2026-09-24" }
    }
  end

  before { allow(Watchlist::EntryZoneSuggester).to receive(:call).and_return(suggestion) }

  def json = JSON.parse(response.body)

  it "previews suggested levels" do
    get "/api/v1/watchlist_items/suggestion", params: { symbol: "nabil", setup_type: "vcp" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json).to include("symbol" => "NABIL", "current_price" => 560.0)
    expect(json["levels"]).to include("entry_zone_low" => 570.0, "target_basis" => "resistance")
  end

  it "adds a stock with suggested levels, a snapshot and its starting state" do
    post "/api/v1/watchlist_items", params: { symbol: "NABIL", setup_type: "vcp", notes: "Tight T3" }, headers: headers, as: :json

    expect(response).to have_http_status(:created)
    expect(json).to include(
      "symbol" => "NABIL", "setup_type" => "vcp", "status" => "watching", "price_state" => "below_zone",
      "entry_zone_low" => 570.0, "invalidation_price" => 548.0, "target_price" => 640.0,
      "price_at_add" => 560.0, "current_price" => 560.0, "distance_to_zone_pct" => 1.79,
      "risk_reward" => 3.18, "notes" => "Tight T3"
    )
    expect(json["setup_snapshot"]).to include("vcp_score" => 72)
  end

  it "lets manual levels override the suggestion" do
    post "/api/v1/watchlist_items", params: { symbol: "NABIL", entry_zone_low: 565, entry_zone_high: 575 }, headers: headers, as: :json

    expect(json).to include("entry_zone_low" => 565.0, "entry_zone_high" => 575.0, "invalidation_price" => 548.0)
  end

  it "explains when no levels can be suggested and none were given" do
    allow(Watchlist::EntryZoneSuggester).to receive(:call).and_return({ success: false, error: "No VCP pivot found for NABIL." })

    post "/api/v1/watchlist_items", params: { symbol: "NABIL" }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["error"]).to eq("No VCP pivot found for NABIL.")
  end

  it "rejects a duplicate and invalid levels with readable errors" do
    post "/api/v1/watchlist_items", params: { symbol: "NABIL" }, headers: headers, as: :json
    post "/api/v1/watchlist_items", params: { symbol: "NABIL" }, headers: headers, as: :json
    expect(json["error"]).to eq("Stock is already on your watchlist")

    item_id = WatchlistItem.last.id
    patch "/api/v1/watchlist_items/#{item_id}", params: { invalidation_price: 580 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["error"]).to eq("Invalidation price must be below the entry zone")
  end

  it "edits levels, restores an invalidated setup and archives it" do
    item = create(:watchlist_item, user: user, stock: stock, status: "invalidated", price_state: "invalidated")

    patch "/api/v1/watchlist_items/#{item.id}", params: { entry_zone_low: 550, entry_zone_high: 565, target_price: 620, status: "watching" }, headers: headers, as: :json
    expect(json).to include("entry_zone_low" => 550.0, "status" => "in_zone", "price_state" => "in_zone")

    patch "/api/v1/watchlist_items/#{item.id}", params: { status: "archived" }, headers: headers, as: :json
    expect(json["status"]).to eq("archived")

    get "/api/v1/watchlist_items", headers: headers
    expect(json).to be_empty
    get "/api/v1/watchlist_items", params: { include_archived: true }, headers: headers
    expect(json.size).to eq(1)
  end

  it "creates a trade plan from the setup and marks the item planned" do
    item = create(:watchlist_item, user: user, stock: stock, setup_snapshot: { "market_regime" => "bullish" })

    post "/api/v1/watchlist_items/#{item.id}/trade_plan", params: { planned_quantity: 20 }, headers: headers, as: :json

    expect(response).to have_http_status(:created)
    plan = TradePlan.find(json["trade_plan_id"])
    expect(plan).to have_attributes(stock: stock, user: user, status: "planned", entry_strategy: "VCP breakout", planned_quantity: 20, market_condition_at_entry: "bullish")
    expect(plan.planned_entry_price.to_f).to eq(500.0)
    expect(plan.stop_loss_price.to_f).to eq(470.0)
    expect(plan.entry_trigger_description).to eq("VCP breakout on NABIL: entry zone 500.00-515.00, invalidated below 470.00.")
    expect(json["watchlist_item"]).to include("status" => "planned", "trade_plan_id" => plan.id)
  end

  it "lists alerts with an unread count and marks them read" do
    item = create(:watchlist_item, user: user, stock: stock)
    2.times { |n| item.alerts.create!(user: user, kind: "extended", message: "Alert #{n}", price: 530) }

    get "/api/v1/watchlist_alerts", headers: headers
    expect(json["unread_count"]).to eq(2)
    expect(json["alerts"].first).to include("symbol" => "NABIL", "kind" => "extended", "price" => 530.0)

    post "/api/v1/watchlist_alerts/mark_read", headers: headers, as: :json
    expect(json["updated"]).to eq(2)
    expect(user.watchlist_alerts.unread.count).to eq(0)
  end

  it "does not expose another user's items" do
    other = create(:watchlist_item, stock: stock)

    patch "/api/v1/watchlist_items/#{other.id}", params: { status: "archived" }, headers: headers, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
