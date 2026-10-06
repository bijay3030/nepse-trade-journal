require "rails_helper"

RSpec.describe "Trading settings and position sizing", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }

  def json = JSON.parse(response.body)

  it "saves capital and risk limits, rejecting out-of-range values" do
    get "/api/v1/trading_settings", headers: headers
    expect(json).to eq("trading_capital" => nil, "risk_per_trade_pct" => 1.0, "max_open_risk_pct" => 6.0, "max_sector_pct" => 30.0)

    patch "/api/v1/trading_settings", params: { trading_capital: 500_000, risk_per_trade_pct: 1.5 }, headers: headers, as: :json
    expect(json).to include("trading_capital" => 500_000.0, "risk_per_trade_pct" => 1.5)

    patch "/api/v1/trading_settings", params: { risk_per_trade_pct: 25 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "suggests a size and prices a typed quantity" do
    user.update!(trading_capital: 500_000)

    get "/api/v1/position_sizing", params: { entry: 505, stop: 470, target: 560, quantity: 100 }, headers: headers
    expect(json).to include("quantity" => 120, "loss_at_stop" => 4628.65)
    expect(json["for_quantity"]).to include("quantity" => 100, "amount" => 50_500.0, "break_even" => be_within(0.5).of(508.7))
  end

  it "adds sizing to watchlist items once capital is set" do
    stock = create(:stock, last_price: 495)
    create(:watchlist_item, user: user, stock: stock) # zone 500-515, stop 470, target 560

    get "/api/v1/watchlist_items", headers: headers
    expect(json.sole["sizing"]).to be_nil

    user.update!(trading_capital: 500_000)
    get "/api/v1/watchlist_items", headers: headers
    # Below the zone: sized at the zone low (500) with the setup's stop.
    expect(json.sole["sizing"]).to include("entry" => 500.0, "stop" => 470.0, "quantity" => 140) # 150 would lose ~5,002 after fees
  end
end
