require "rails_helper"

RSpec.describe PaperTrading::Engine do
  let(:zone) { ActiveSupport::TimeZone["Asia/Kathmandu"] }
  let(:monday) { zone.parse("2026-11-23 11:30") }
  let(:client) { instance_double(Telegram::Client, send_message: {}) }
  let!(:user) { create(:user, telegram_chat_id: "42") }
  let(:stock) { create(:stock, symbol: "AHPC", name: "Arun Valley", security_type: "Equity", last_price: 260.0, last_updated: monday) }
  let!(:item) do
    create(:watchlist_item, user: user, stock: stock, entry_zone_low: 259.6, entry_zone_high: 264.79, invalidation_price: 251.81,
                            stop_loss_price: 251.81, target_price: 290, pivot_price: 260)
  end

  def alert!(kind = "entered_zone", at: monday) = WatchlistAlert.create!(user: user, watchlist_item: item, kind: kind, message: "x", price: 260.0, created_at: at)
  def price!(value, at) = stock.update!(last_price: value, last_updated: at)

  it "buys 10 shares at the live price plus slippage when a watchlist stock enters its zone, and logs why" do
    alert!
    described_class.on_live(now: monday, client: client)

    trade = PaperTrade.sole
    expect(trade).to have_attributes(status: "open", quantity: 10, trigger: "watchlist_entered_zone", entry_price: 261.3, stop_price: 251.81, target_price: 290)
    expect(trade.buy_costs.to_f).to eq(Nepse::Costs.buy_costs(2613.0))
    expect(trade.events.pluck(:action)).to eq(%w[signal buy])
    expect(trade.events.last.reason).to include("Bought 10 at 261.30 (live 260.00 + 0.5% slippage)", "Watchlist alert: AHPC entered its zone at 260.00")
    expect(client).to have_received(:send_message).with("42", include("🟢 Paper BUY · <b>AHPC</b> 10 @ 261.30", "Stop 251.81 · target 290.00", "no real order")).once
  end

  it "skips a second signal for a stock it already holds, logging it once" do
    alert!
    described_class.on_live(now: monday, client: client)
    alert!("breakout_confirmed", at: monday + 10.minutes)
    2.times { described_class.on_live(now: monday + 15.minutes, client: client) }

    expect(PaperTrade.count).to eq(1)
    expect(PaperTradeEvent.where(action: "skip").sole.reason).to eq("AHPC signal skipped: already holding it (since 23 Nov).")
  end

  it "holds through a stop hit before the shares settle (T+2), then sells at the stop with costs" do
    alert!
    described_class.on_live(now: monday, client: client)

    price!(250.0, monday + 1.day)
    2.times { described_class.on_live(now: monday + 1.day, client: client) }
    trade = PaperTrade.sole
    expect(trade.status).to eq("open")
    expect(trade.events.where(action: "hold").sole.reason).to include("Not sold yet", "settle (T+2) on 25 Nov")

    price!(249.0, monday + 2.days)
    described_class.on_live(now: monday + 2.days, client: client)
    trade.reload
    expect(trade).to have_attributes(status: "closed", exit_rule: "stop_hit", exit_price: (249.0 * 0.995).round(2), cgt: 0)
    expected = (Nepse::Costs.net_proceeds(trade.exit_price.to_f, 10) - trade.cost_basis).round(2)
    expect(trade.net_pnl.to_f).to eq(expected)
    expect(trade.events.last.reason).to include("Sold 10 at 247.76", "at or under the 251.81 stop", "held 2 days")
  end

  it "sells at the target with capital gains tax on the gain" do
    alert!
    described_class.on_live(now: monday, client: client)
    price!(292.0, monday + 3.days)
    described_class.on_live(now: monday + 3.days, client: client)

    trade = PaperTrade.sole
    gain = Nepse::Costs.net_proceeds((292.0 * 0.995).round(2), 10) - trade.cost_basis
    expect(trade).to have_attributes(status: "closed", exit_rule: "target_reached", cgt: (gain * 0.10).round(2))
    expect(client).to have_received(:send_message).with("42", include("🔴 Paper SELL · <b>AHPC</b> 10 @ 290.54", "Result: +Rs")).once
  end

  it "queues a stock new on the board and buys it at the next session's first live price" do
    session = Date.new(2026, 11, 20)
    board = create(:stock, symbol: "EBL", security_type: "Equity", last_price: 714.5, last_updated: zone.parse("2026-11-20 15:00"))
    StockSetupSnapshot.create!(stock: board, traded_on: session, close_price: 714.5, zone_state: "in_zone", in_buy_zone: true, readiness_score: 87,
                               trend_rules_passed: 6, setup_type: "ma_pullback", entry_zone_low: 714.37, entry_zone_high: 728.66, invalidation_price: 685.8, target_price: 771.52)

    described_class.on_board(session, now: zone.parse("2026-11-20 17:00"), client: client)
    trade = PaperTrade.sole
    expect(trade).to have_attributes(status: "pending", trigger: "board_new", stop_price: 685.8)
    expect(trade.buy_reason).to include("New on Entry zone now after the 20 Nov close: Pullback to a rising average, readiness 87")

    described_class.on_live(now: zone.parse("2026-11-23 10:00"), client: client) # prices still from Friday
    expect(trade.reload.status).to eq("pending")
    board.update!(last_price: 716.0, last_updated: monday)
    described_class.on_live(now: monday, client: client)
    expect(trade.reload).to have_attributes(status: "open", entry_price: (716.0 * 1.005).round(2))
  end

  it "sells on a close-time rule at the close" do
    alert!
    described_class.on_live(now: monday, client: client)
    allow(Positions::Monitor).to receive(:close_rules).and_return([ [ "time_stop", "", "AHPC has gone 15 sessions at 0.1R." ] ])

    described_class.on_close(now: monday + 3.days + 5.hours, client: client)
    expect(PaperTrade.sole).to have_attributes(status: "closed", exit_rule: "time_stop", exit_price: 260.0)
  end

  it "does nothing for users who turned it off" do
    user.update!(paper_trading: false)
    alert!
    described_class.on_live(now: monday, client: client)
    expect(PaperTrade.count).to eq(0)
  end
end
