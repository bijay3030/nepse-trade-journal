require "rails_helper"

RSpec.describe Telegram::Notifier do
  let(:client) { instance_double(Telegram::Client, send_message: {}) }
  let(:user) { create(:user, telegram_chat_id: "42") }
  let(:stock) { create(:stock, symbol: "NABIL", name: "Nabil Bank", last_price: 505) }
  let(:item) { create(:watchlist_item, user: user, stock: stock) }


  before do
    allow(TelegramAlertJob).to receive(:perform_later)
    StockSetupSnapshot.create!(stock: stock, traded_on: Date.new(2026, 9, 28), close_price: 500, zone_state: "too_early",
                               readiness_score: 63, trend_rules_passed: 6, rs_rating: 86, guards: [ "thin_volume" ])
  end

  describe ".watchlist_alert" do
    def zone_alert(kind = "entered_zone", at: Time.zone.parse("2026-09-29 07:00"))
      user.watchlist_alerts.create!(watchlist_item: item, kind: kind, message: "x", price: 505, relative_volume: 1.8, created_at: at)
    end

    it "sends levels and setup context for a zone entry, once per stock per day" do
      expect(described_class.watchlist_alert(zone_alert, client: client)).to eq(:sent)
      expect(client).to have_received(:send_message) do |chat_id, text|
        expect(chat_id).to eq("42")
        expect(text).to include("🟢 <b>NABIL</b> is in its entry zone", "Price 505.00 · volume 1.8x average",
                                "Zone 500.00–515.00 · stop 470.00 · target 560.00 · R:R 2.0",
                                "VCP breakout · readiness 63/100 · trend 6/7 · RS 86", "⚠️ thin volume", "Rule checks, not a recommendation.")
        expect(text).not_to match(/\bbuy\b|\bsell\b/i)
      end

      expect(described_class.watchlist_alert(zone_alert("breakout_confirmed"), client: client)).to eq(:duplicate)
      expect(described_class.watchlist_alert(zone_alert(at: Time.zone.parse("2026-09-30 07:00")), client: client)).to eq(:sent)
    end

    it "skips other alert kinds, unlinked users and users who switched these off" do
      expect(described_class.watchlist_alert(zone_alert("invalidated"), client: client)).to eq(:skipped)
      user.update!(telegram_watchlist_alerts: false)
      expect(described_class.watchlist_alert(zone_alert, client: client)).to eq(:skipped)
      user.update!(telegram_watchlist_alerts: true, telegram_chat_id: nil)
      expect(described_class.watchlist_alert(zone_alert, client: client)).to eq(:skipped)
      expect(client).not_to have_received(:send_message)
    end

    it "warns about a bonus book close within 10 days" do
      stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: Nepse::MarketHours.today + 3, source: "chukul")

      described_class.watchlist_alert(zone_alert, client: client)
      expect(client).to have_received(:send_message).with("42", /10.0% bonus book close .*: price and levels will be adjusted/)
    end

    it "unlinks a chat that blocked the bot" do
      allow(client).to receive(:send_message).and_raise(Telegram::Error.new("Forbidden: bot was blocked by the user", code: 403))

      expect(described_class.watchlist_alert(zone_alert, client: client)).to eq(:failed)
      expect(user.reload.telegram_chat_id).to be_nil
    end
  end

  describe ".entry_zone_board" do
    let(:today) { Date.new(2026, 9, 29) }

    def board(stock, day, on:, readiness: 70)
      StockSetupSnapshot.create!(stock: stock, traded_on: day, close_price: 224, zone_state: on ? "in_zone" : "too_early", in_buy_zone: on,
                                 readiness_score: readiness, trend_rules_passed: 6, setup_type: "vcp", entry_zone_low: 221,
                                 entry_zone_high: 227.63, invalidation_price: 207.1, target_price: 250)
    end

    it "sends each linked user the stocks new on the board since the previous session, once" do
      user
      kbl = create(:stock, symbol: "KBL", name: "Kumari Bank")
      stay = create(:stock, symbol: "STAY")
      board(kbl, Date.new(2026, 9, 28), on: false)
      board(kbl, today, on: true, readiness: 69)
      board(stay, Date.new(2026, 9, 28), on: true)
      board(stay, today, on: true)
      off = create(:user, telegram_chat_id: "43", telegram_board_alerts: false)

      expect(described_class.entry_zone_board(today, client: client)).to eq(user.id => :sent)
      expect(client).to have_received(:send_message).once.with("42", satisfy do |text|
        text.include?("📋 <b>New on Entry zone now</b> (Sep 29 close): 1 stock") &&
          text.include?("<b>KBL</b> · Kumari Bank") &&
          text.include?("Close 224.00 · zone 221.00–227.63 · stop 207.10 · target 250.00 · R:R 1.54") &&
          text.include?("VCP breakout · readiness 69/100 · trend 6/7") && !text.include?("STAY")
      end)
      expect(off.telegram_deliveries).to be_empty

      expect(described_class.entry_zone_board(today, client: client)).to eq(user.id => :duplicate)
    end

    it "sends nothing when no stock is new" do
      expect(described_class.entry_zone_board(today, client: client)).to eq({})
    end
  end
end
