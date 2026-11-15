require "rails_helper"

RSpec.describe Scans::EntryAlerts do
  let(:none) { Scans::Crossovers::SIGNALS.index_with { nil } }
  let(:open_time) { Time.find_zone("Asia/Kathmandu").parse("2026-11-16 12:30") } # a Monday, market open
  let(:levels) { { entry_low: 500.0, entry_high: 515.0, stop: 470.0, target: 560.0, source: "board_setup", setup_type: "vcp" } }

  def row(symbol, signals, extra = {})
    { symbol: symbol, name: "#{symbol} Ltd", close: 498.0, signals: none.merge(signals), signal_volume: { "ema_9_21" => 1.8, "ema_stack" => 0.9 },
      readiness: 72, in_buy_zone: true, guards: [], levels: levels, **extra }
  end

  it "puts a stock on the radar when every saved signal holds within the window" do
    expect(described_class.on_radar?(row("A", { "ema_9_21" => 4 }), %w[ema_9_21])).to be(true)
    expect(described_class.on_radar?(row("A", { "ema_9_21" => 11 }), %w[ema_9_21])).to be(false) # began 11 sessions ago
    expect(described_class.on_radar?(row("A", { "ema_9_21" => 2, "ema_stack" => 40 }), %w[ema_9_21 ema_stack])).to be(true) # a state only has to hold
    expect(described_class.on_radar?(row("A", { "ema_9_21" => 2 }), %w[ema_9_21 ema_stack])).to be(false)
    expect(described_class.on_radar?(row("A", { "ema_9_21" => 2 }), [])).to be(false)
  end

  it "applies the volume rule to the newest saved signal" do
    expect(described_class.on_radar?(row("A", { "ema_9_21" => 2, "ema_stack" => 40 }), %w[ema_9_21 ema_stack], volume: true)).to be(true) # 9/21 on 1.8x
    expect(described_class.on_radar?(row("A", { "ema_9_21" => 50, "ema_stack" => 3 }), %w[ema_stack], volume: true)).to be(false) # stack on 0.9x
  end

  it "is entry-ready inside the zone with readiness 60+ and no blocking guard" do
    ready = row("A", {})
    expect(described_class.entry_ready?(ready, 505)).to be(true)
    expect(described_class.entry_ready?(ready, 499)).to be(false) # below the zone
    expect(described_class.entry_ready?(ready, 520)).to be(false) # above it (chasing)
    expect(described_class.entry_ready?(ready.merge(readiness: 59), 505)).to be(false)
    expect(described_class.entry_ready?(ready.merge(guards: [ "extended" ]), 505)).to be(false)
    expect(described_class.entry_ready?(ready.merge(guards: [ "late_stage_base" ]), 505)).to be(true) # a warning, not a block
    expect(described_class.entry_ready?(ready.merge(levels: nil), 505)).to be(false)
  end

  describe ".deliver" do
    let(:client) { instance_double(Telegram::Client, send_message: {}) }
    let!(:user) { create(:user, telegram_chat_id: "42", scanner_alert_signals: %w[ema_9_21]) }
    let(:scan) { { rows: [ row("INZN", { "ema_9_21" => 1 }), row("OUTZ", { "ema_9_21" => 1 }), row("NOTR", {}) ] } }

    before do
      create(:stock, symbol: "INZN", security_type: "Equity", last_price: 505, last_updated: open_time - 5.minutes)
      create(:stock, symbol: "OUTZ", security_type: "Equity", last_price: 530, last_updated: open_time - 5.minutes)
      create(:stock, symbol: "NOTR", security_type: "Equity", last_price: 505, last_updated: open_time - 5.minutes)
      create(:user, telegram_chat_id: "43") # no filter saved
    end

    it "sends the stocks on the user's radar that trade in their zone, once per session" do
      expect(described_class.deliver(now: open_time, scan: scan, client: client)).to eq(user.id => :sent)
      expect(client).to have_received(:send_message).with("42", include("Entry-ready on your scanner filter", "<b>INZN</b>", "Live 505.00 · in entry zone 500.00–515.00 · stop 470.00 · target 560.00 · R:R 1.57", "EMA 9/21 cross 1d ago (1.8x vol)")).once
      expect(client).not_to have_received(:send_message).with(anything, include("OUTZ"))
      expect(client).not_to have_received(:send_message).with(anything, include("NOTR"))

      expect(described_class.deliver(now: open_time + 5.minutes, scan: scan, client: client)).to eq(user.id => :duplicate)
    end

    it "respects the switch, and does nothing outside market hours or with yesterday's prices" do
      expect(described_class.deliver(now: open_time.change(hour: 18), scan: scan, client: client)).to eq({})
      Stock.update_all(last_updated: open_time - 1.day)
      expect(described_class.deliver(now: open_time, scan: scan, client: client)).to eq(user.id => :none)
      user.update!(telegram_scanner_entry_alerts: false)
      expect(described_class.deliver(now: open_time, scan: scan, client: client)).to eq({})
      expect(client).not_to have_received(:send_message)
    end
  end
end
