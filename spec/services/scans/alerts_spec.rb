require "rails_helper"

RSpec.describe Scans::Alerts do
  let(:none) { Scans::Crossovers::SIGNALS.index_with { nil } }
  let(:today) { Date.new(2026, 11, 6) }
  let(:backtest) do
    { signals: { "all" => { 20 => { avg_return_pct: -0.12 } }, "ema_9_21" => { 20 => { avg_return_pct: -2.83 } }, "aroon_strong" => { 20 => { avg_return_pct: -2.69 } } } }
  end

  def row(symbol, signals, extra = {})
    { symbol: symbol, close: 512.0, change_pct: 2.1, signals: none.merge(signals), readiness: 64, in_buy_zone: false, guards: [], **extra }
  end

  let(:scan) do
    {
      as_of: today, backtest: backtest,
      rows: [
        row("NEWX", { "ema_9_21" => 0, "aroon_strong" => 3 }, in_buy_zone: true), # 9/21 switched on today: new
        row("KEEP", { "ema_9_21" => 2, "aroon_strong" => 5 }),                     # matched already yesterday
        row("HALF", { "ema_9_21" => 0 }),                                          # Aroon doesn't hold
        row("THIN", { "ema_9_21" => 0, "aroon_strong" => 0 }, guards: [ "thin_volume" ])
      ]
    }
  end

  it "finds liquid stocks where the whole combination switched on at the latest session" do
    expect(described_class.new_matches(scan, %w[ema_9_21 aroon_strong]).map { _1[:symbol] }).to eq([ "NEWX" ])
    expect(described_class.new_matches(scan, %w[aroon_strong]).map { _1[:symbol] }).to eq([]) # Aroon began 3 days ago for NEWX
    expect(described_class.new_matches(scan, [])).to eq([])
  end

  describe ".deliver" do
    let(:client) { instance_double(Telegram::Client, send_message: {}) }
    let!(:user) { create(:user, telegram_chat_id: "42", scanner_alert_signals: %w[ema_9_21 aroon_strong]) }

    before do
      create(:stock, symbol: "NEWX")
      create(:user, telegram_chat_id: "43") # no filter saved
    end

    it "sends one message per user with the new matches and the track record, once per session" do
      expect(described_class.deliver(scan: scan, today: today, client: client)).to eq(user.id => :sent)
      expect(client).to have_received(:send_message).once.with("42", satisfy { |text|
        text.include?("📈 <b>Indicator scanner</b> (Nov 6 close): 1 stock newly matches EMA 9/21 cross + Aroon Up ≥ 70") &&
          text.include?("• <b>NEWX</b> 512.00 (+2.10%) · EMA 9/21 cross today, Aroon Up ≥ 70 3d · readiness 64 · also on Entry zone now") &&
          text.include?("Track record on NEPSE (20 sessions after each signal began): EMA 9/21 cross -2.8%, Aroon Up ≥ 70 -2.7% vs -0.1% for all stock-days.") &&
          text.include?("Rule checks, not a recommendation.")
      })

      expect(described_class.deliver(scan: scan, today: today, client: client)).to eq(user.id => :duplicate)
    end

    it "sends nothing for a stale scan" do
      expect(described_class.deliver(scan: scan, today: today + 1, client: client)).to eq({})
      expect(client).not_to have_received(:send_message)
    end
  end
end
