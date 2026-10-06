require "rails_helper"

RSpec.describe "Position alerts", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }
  let(:stock) { create(:stock, symbol: "NABIL", last_price: 109) }
  let(:position) do
    user.positions.create!(stock: stock, stop_price: 92, initial_stop_price: 92).tap do |p|
      p.fills.create!(side: "buy", price: 100, quantity: 100, traded_on: Date.new(2026, 9, 24))
    end
  end

  it "lists the user's alerts with the break-even for a +1R alert, and marks them read" do
    alert = user.position_alerts.create!(position: position, kind: "one_r", message: "NABIL is up 1R", price: 109)
    create(:user).position_alerts.create!(position: position, kind: "stop_hit", message: "other user", key: "92.00")

    get "/api/v1/position_alerts", headers: headers

    body = response.parsed_body
    expect(body["unread_count"]).to eq(1)
    expect(body["alerts"].sole).to include("id" => alert.id, "kind" => "one_r", "symbol" => "NABIL", "position_open" => true,
                                           "stop_price" => 92.0, "break_even_price" => position.break_even_price)

    post "/api/v1/position_alerts/mark_read", headers: headers
    expect(alert.reload.read_at).to be_present
  end
end
