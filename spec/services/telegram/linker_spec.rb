require "rails_helper"

RSpec.describe Telegram::Linker do
  let(:client) { instance_double(Telegram::Client, bot_username: "nepse_journal_bot", send_message: {}) }
  let(:user) { create(:user, email: "trader@example.com") }

  def message(text, chat_id: 42, update_id: 1, type: "private")
    { "update_id" => update_id, "message" => { "text" => text, "chat" => { "id" => chat_id, "type" => type }, "from" => { "username" => "trader" } } }
  end

  it "gives a one-time code and deep link, and links the chat that sends it" do
    link = described_class.start(user, client: client)
    code = user.reload.telegram_link_token
    expect(code).to match(/\A[A-HJ-NP-Z2-9]{8}\z/)
    expect(link).to eq(code: code, bot_username: "nepse_journal_bot", url: "https://t.me/nepse_journal_bot?start=#{code}")

    allow(client).to receive(:get_updates).with(offset: nil).and_return([ message("/start #{code}", update_id: 7) ])
    expect(described_class.poll(client: client)).to eq(1)

    expect(user.reload).to have_attributes(telegram_chat_id: "42", telegram_username: "trader", telegram_link_token: nil)
    expect(client).to have_received(:send_message).with("42", /Connected to NEPSE Trade Journal \(trader@example.com\)/)
    expect(AppSetting.get(described_class::OFFSET_KEY)).to eq("8")

    allow(client).to receive(:get_updates).with(offset: 8).and_return([])
    expect(described_class.poll(client: client)).to eq(0)
  end

  it "accepts the code sent on its own, in any case, when the deep link lost it" do
    described_class.start(user, client: client)
    code = user.reload.telegram_link_token
    allow(client).to receive(:get_updates).and_return([ message("/start"), message(" #{code.downcase} ", update_id: 2) ])

    expect(described_class.poll(client: client)).to eq(1)
    expect(user.reload.telegram_chat_id).to eq("42")
    expect(client).to have_received(:send_message).with("42", /send me the 8-character code/)
  end

  it "rejects an expired or unknown code, and ignores group chats" do
    described_class.start(user, client: client)
    code = user.reload.telegram_link_token
    user.update!(telegram_link_expires_at: 1.minute.ago)
    allow(client).to receive(:get_updates).and_return([ message("/start #{code}"), message("ABCD2345", update_id: 2), message("/start #{code}", update_id: 3, type: "group") ])

    expect(described_class.poll(client: client)).to eq(0)
    expect(user.reload.telegram_chat_id).to be_nil
    expect(client).to have_received(:send_message).with("42", /isn't valid or has expired/).twice
  end

  it "moves a chat to the account that links it last, and unlinks on /stop" do
    other = create(:user, telegram_chat_id: "42")
    described_class.start(user, client: client)
    allow(client).to receive(:get_updates).and_return([ message("/start #{user.reload.telegram_link_token}") ])
    described_class.poll(client: client)
    expect(other.reload.telegram_chat_id).to be_nil

    allow(client).to receive(:get_updates).and_return([ message("/stop", update_id: 2) ])
    expect(described_class.poll(client: client)).to eq(1)
    expect(user.reload.telegram_chat_id).to be_nil
    expect(client).to have_received(:send_message).with("42", /Disconnected/)
  end
end
