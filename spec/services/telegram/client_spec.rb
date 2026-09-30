require "rails_helper"

RSpec.describe Telegram::Client do
  let(:client) { described_class.new(token: "123:secret") }

  def respond(body, code: 200)
    response = instance_double(HTTParty::Response, parsed_response: body, code: code)
    allow(HTTParty).to receive(:post).and_return(response)
  end

  it "posts JSON to the Bot API and returns the result" do
    respond({ "ok" => true, "result" => { "message_id" => 5 } })

    expect(client.send_message("42", "<b>hi</b>")).to eq("message_id" => 5)
    expect(HTTParty).to have_received(:post).with(
      "https://api.telegram.org/bot123:secret/sendMessage",
      hash_including(body: { chat_id: "42", text: "<b>hi</b>", parse_mode: "HTML", disable_web_page_preview: true }.to_json)
    )
  end

  it "raises with Telegram's description and the HTTP code" do
    respond({ "ok" => false, "description" => "Forbidden: bot was blocked by the user" }, code: 403)

    expect { client.send_message("42", "x") }.to raise_error(Telegram::Error) { |error|
      expect(error.message).to eq("Forbidden: bot was blocked by the user")
      expect(error.chat_unreachable?).to be(true)
    }
  end

  it "never puts the token in a network error" do
    allow(HTTParty).to receive(:post).and_raise(Net::ReadTimeout)

    expect { client.get_updates }.to raise_error(Telegram::Error) { |error| expect(error.message).not_to include("secret") }
  end

  it "is off without a token" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TELEGRAM_BOT_TOKEN").and_return(nil)

    expect(described_class.configured?).to be(false)
    expect { described_class.new }.to raise_error(Telegram::Error, /TELEGRAM_BOT_TOKEN/)
  end
end
