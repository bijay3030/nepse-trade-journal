require "rails_helper"

RSpec.describe Scans::MorningWatch do
  let(:none) { Scans::Crossovers::SIGNALS.index_with { nil } }
  let(:monday) { Time.find_zone("Asia/Kathmandu").parse("2026-11-16 09:00") }
  let(:levels) { { entry_low: 500.0, entry_high: 515.0, stop: 470.0, target: 560.0, source: "board_setup", setup_type: "vcp" } }

  def row(symbol, close, extra = {})
    { symbol: symbol, name: "#{symbol} Ltd", close: close, signals: none.merge("ema_9_21" => 2), signal_volume: { "ema_9_21" => 1.8 },
      readiness: 70, in_buy_zone: false, guards: [], levels: levels, **extra }
  end

  let(:scan) do
    {
      as_of: Date.new(2026, 11, 13),
      rows: [
        row("INZN", 505.0, readiness: 80, in_buy_zone: true),
        row("NEAR", 490.0),                                         # 2.0% below the zone
        row("FAR", 470.5),                                          # 6.3% below
        row("HIGH", 530.0),                                         # above the zone (chasing)
        row("STOP", 470.0),                                         # at the stop
        row("THIN", 505.0, guards: [ "thin_volume" ]),
        row("OLD", 505.0, signals: none.merge("ema_9_21" => 12)),  # cross began 12 sessions ago
        row("NOLV", 505.0, levels: nil)
      ]
    }
  end

  it "lists the radar's stocks in their zone and those within 3% below it" do
    groups = described_class.watch(scan, %w[ema_9_21])
    expect(groups[:in_zone].map { _1[:symbol] }).to eq([ "INZN" ])
    expect(groups[:near].map { |r, gap| [ r[:symbol], gap ] }).to eq([ [ "NEAR", 2.0 ] ])
    expect(groups[:radar]).to eq(5) # INZN NEAR FAR HIGH STOP
  end

  describe ".deliver" do
    let(:client) { instance_double(Telegram::Client, send_message: {}) }
    let!(:user) { create(:user, telegram_chat_id: "42", scanner_alert_signals: %w[ema_9_21]) }

    before { create(:user, telegram_chat_id: "43") } # no filter saved

    it "sends one message on a trading morning, not twice" do
      expect(described_class.deliver(now: monday, scan: scan, client: client)).to eq(user.id => :sent)
      expect(client).to have_received(:send_message).with("42", include(
        "Morning watch</b> · Mon Nov 16 (levels from the Nov 13 close)", "Filter: EMA 9/21 cross on 1.5x volume",
        "<b>In entry zone</b> (1)", "<b>INZN</b> 505.00 · zone 500.00–515.00 · stop 470.00 · target 560.00 · R:R 1.57",
        "readiness 80 · on Entry zone now · EMA 9/21 cross 2d (1.8x vol)",
        "<b>Close to the zone</b> (≤3% below, 1)", "<b>NEAR</b> 490.00 · 2.0% below zone",
        "You'll get a 🎯 message if one trades inside its zone."
      )).once
      expect(described_class.deliver(now: monday + 1.hour, scan: scan, client: client)).to eq(user.id => :duplicate)
    end

    it "tries again on a later run when Telegram didn't take the message" do
      failing = instance_double(Telegram::Client)
      allow(failing).to receive(:send_message).and_raise(Telegram::Error.new("Not Found", code: 404))

      expect(described_class.deliver(now: monday, scan: scan, client: failing)).to eq(user.id => :failed)
      expect(described_class.deliver(now: monday + 10.minutes, scan: scan, client: client)).to eq(user.id => :sent)
    end

    it "says so when nothing is in or near a zone, and skips non-trading days and users who turned it off" do
      quiet = scan.merge(rows: [ row("FAR", 470.5) ])
      described_class.deliver(now: monday, scan: quiet, client: client)
      expect(client).to have_received(:send_message).with("42", include("No stock on your radar is in or within 3% of its entry zone (1 stock matches the filter)."))

      expect(described_class.deliver(now: monday - 1.day, scan: scan, client: client)).to eq({}) # Sunday
      user.update!(telegram_morning_watch: false)
      expect(described_class.deliver(now: monday + 1.day, scan: scan, client: client)).to eq({})
    end

    it "shows fewer stocks per group when the message would be too long for Telegram" do
      many = scan.merge(rows: (1..40).map { |i| row("S#{i}", 505.0, signals: none.merge(Scans::Crossovers::SIGNALS.index_with { 2 })) })
      user.update!(scanner_alert_signals: Scans::Crossovers::SIGNALS, scanner_alert_volume: false)
      described_class.deliver(now: monday, scan: many, client: client)
      expect(client).to have_received(:send_message).with("42", satisfy { |text| text.size <= Telegram::Messages::MAX_LENGTH && text.include?("more on the Indicator Scanner") })
    end
  end
end
