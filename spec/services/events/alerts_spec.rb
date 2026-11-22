require "rails_helper"

RSpec.describe Events::Alerts do
  let(:today) { Date.new(2026, 11, 22) }
  let(:client) { instance_double(Telegram::Client, send_message: {}) }
  let!(:user) { create(:user, telegram_chat_id: "42") }
  let(:mine) { create(:stock, symbol: "MINE", name: "Mine Limited") }
  let(:other) { create(:stock, symbol: "OTHR", name: "Other Limited") }

  def event(stock, kind:, impact: "neutral", important: false, published_on: today, event_on: nil, data: {})
    MarketEvent.create!(stock: stock, source: "sharesansar", external_id: SecureRandom.hex(4), kind: kind, impact: impact, important: important,
                        title: "#{stock&.name} notice", reason: "#{kind} reason", published_on: published_on, event_on: event_on, data: data)
  end

  before do
    create(:watchlist_item, user: user, stock: mine)
    allow(described_class).to receive(:lab_stock_ids).and_return(Set.new)
  end

  it "sends the user's stocks' events, important market-wide ones and book closes ahead, once" do
    event(mine, kind: "results", impact: "negative")
    event(other, kind: "agm")                                                 # market-wide but minor: not sent
    event(other, kind: "rights", impact: "mixed", important: true)            # market-wide, important
    event(other, kind: "bonus", impact: "positive", important: true, published_on: today - 10, event_on: today + 2, data: { "bonus" => 12, "cash" => 3 })
    event(mine, kind: "results", published_on: today - 5)                     # too old to be news

    expect(described_class.deliver(today: today, client: client)).to eq(user.id => :sent)
    expect(client).to have_received(:send_message).with("42", satisfy { |text|
      text.include?("<b>Your stocks</b>\n🔴 <b>MINE</b>: results reason") && text.include?("<b>Market-wide</b>\n🟡 <b>OTHR</b>: rights reason") &&
        text.include?("📅 <b>OTHR</b> Tue 24 Nov: 12% bonus + 3% cash.") && !text.include?("agm reason")
    })

    expect(described_class.deliver(today: today, client: client)).to eq(user.id => :none)
  end

  it "respects the switch" do
    event(mine, kind: "results")
    user.update!(telegram_event_alerts: false)
    expect(described_class.deliver(today: today, client: client)).to eq({})
  end
end
