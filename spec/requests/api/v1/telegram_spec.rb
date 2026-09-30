require "rails_helper"

RSpec.describe "Telegram settings", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JWT.encode({ jti: user.jti, sub: user.id }, 'secret', 'HS256')}" } }
  let(:client) { instance_double(Telegram::Client, bot_username: "nepse_journal_bot", send_message: {}, get_updates: []) }

  def json = JSON.parse(response.body)

  before do
    allow(Telegram::Client).to receive(:configured?).and_return(true)
    allow(Telegram::Client).to receive(:new).and_return(client)
  end

  it "reports the status and returns a one-time link" do
    get "/api/v1/telegram", headers: headers
    expect(json).to include("configured" => true, "linked" => false, "pending" => false, "watchlist_alerts" => true, "board_alerts" => true)

    post "/api/v1/telegram/link", headers: headers
    expect(json["link_url"]).to eq("https://t.me/nepse_journal_bot?start=#{user.reload.telegram_link_token}")
    expect(json["pending"]).to be(true)
  end

  it "checks for the Start message, saves the switches, sends a test and unlinks" do
    post "/api/v1/telegram/link", headers: headers
    allow(client).to receive(:get_updates).and_return(
      [ { "update_id" => 1, "message" => { "text" => "/start #{user.reload.telegram_link_token}", "chat" => { "id" => 42, "type" => "private" }, "from" => { "username" => "trader" } } } ]
    )

    post "/api/v1/telegram/check", headers: headers
    expect(json).to include("linked" => true, "username" => "trader")

    patch "/api/v1/telegram", params: { board_alerts: false }, headers: headers, as: :json
    expect(json).to include("board_alerts" => false, "watchlist_alerts" => true)

    post "/api/v1/telegram/test", headers: headers
    expect(json["sent"]).to be(true)
    expect(client).to have_received(:send_message).with("42", /Test message/)

    delete "/api/v1/telegram", headers: headers
    expect(json["linked"]).to be(false)
  end

  it "explains when the bot token isn't set" do
    allow(Telegram::Client).to receive(:configured?).and_return(false)

    post "/api/v1/telegram/link", headers: headers
    expect(response).to have_http_status(:service_unavailable)
    expect(json["error"]).to include("TELEGRAM_BOT_TOKEN")
  end
end
