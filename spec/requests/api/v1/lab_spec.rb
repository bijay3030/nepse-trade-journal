require "rails_helper"

RSpec.describe "Strategy Lab", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }

  it "returns the leaderboard, candidates and paper trades" do
    stock = create(:stock, symbol: "LABX", security_type: "Equity")
    (1..240).each { |i| create(:stock_daily_price, stock: stock, traded_on: Date.new(2025, 6, 1) + i, close_price: 100 + 10 * Math.sin(i / 6.0)) }

    get "/api/v1/lab", headers: headers

    body = response.parsed_body
    expect(response).to have_http_status(:ok)
    expect(body["strategies"].map { _1["key"] }).to eq(%w[rsi_reversion range_grid])
    expect(body["leaderboard"].keys).to eq(%w[rsi_reversion range_grid])
    expect(body["rules"]).to include("min_trades" => 10, "min_profit_factor" => 1.3)
    expect(body).to include("candidates", "qualifying", "paper_trades", "market_phase")
    expect(body["paper_trades"]["summary"]).to include("total" => 0)
  end
end
