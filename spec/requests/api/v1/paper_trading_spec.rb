require "rails_helper"

RSpec.describe "Paper trading", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }

  it "shows the account with trades and the log, and turns it off" do
    stock = create(:stock, symbol: "AHPC", last_price: 270)
    trade = PaperTrade.create!(user: user, stock: stock, trigger: "board_new", trigger_key: "k", signal_on: Date.new(2026, 11, 20), buy_reason: "New on board",
                               quantity: 10, stop_price: 250, initial_stop_price: 250, target_price: 300, status: "open", entry_price: 261.3,
                               entry_at: Time.zone.parse("2026-11-23 06:00"), buy_costs: 10)
    PaperTradeEvent.create!(user: user, paper_trade: trade, stock: stock, action: "buy", price: 261.3, reason: "Bought 10", at: Time.current)

    get "/api/v1/paper_trading", headers: headers
    body = response.parsed_body
    expect(body["summary"]).to include("open" => 1, "closed" => 0)
    expect(body["trades"].sole).to include("symbol" => "AHPC", "status" => "open", "entry_price" => 261.3, "buy_reason" => "New on board")
    expect(body["log"].sole).to include("action" => "buy", "reason" => "Bought 10")

    patch "/api/v1/paper_trading", params: { enabled: false }, headers: headers, as: :json
    expect(response.parsed_body["enabled"]).to be(false)
  end
end
