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

  describe ".token" do
    around do |example|
      saved = ENV.slice("TELEGRAM_BOT_TOKEN", "TELEGRAM_IN_DEVELOPMENT")
      example.run
    ensure
      ENV.update(saved)
      %w[TELEGRAM_BOT_TOKEN TELEGRAM_IN_DEVELOPMENT].each { ENV.delete(_1) unless saved.key?(_1) }
    end

    let(:real) { "123456789:AAH#{'x' * 32}" }

    # rails_helper stubs .token to nil everywhere; these examples test the real one.
    before { allow(described_class).to receive(:token).and_call_original }

    it "uses a well-formed TELEGRAM_BOT_TOKEN" do
      ENV["TELEGRAM_BOT_TOKEN"] = real
      expect(described_class.token).to eq(real)
    end

    it "ignores a malformed TELEGRAM_BOT_TOKEN and falls back to the credential" do
      ENV["TELEGRAM_BOT_TOKEN"] = "not-a-real-token-1234"
      allow(described_class).to receive(:credential_token).and_return(real)
      allow(Rails.env).to receive(:development?).and_return(false)

      expect(described_class.token).to eq(real)
    end
  end

  it "is off without a token (rails_helper hides the real one)" do
    expect(described_class.configured?).to be(false)
    expect { described_class.new }.to raise_error(Telegram::Error, /TELEGRAM_BOT_TOKEN/)
  end
end
