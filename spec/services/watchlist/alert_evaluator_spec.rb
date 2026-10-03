require "rails_helper"

RSpec.describe Watchlist::AlertEvaluator do
  let(:stock) { create(:stock, symbol: "NABIL", last_price: 490.0, volume: 0) }
  # Zone 500-515, invalidation 470, pivot 500.
  let!(:item) { create(:watchlist_item, stock: stock, price_state: "below_zone") }

  def move_to(price, volume: 0)
    stock.update!(last_price: price, volume: volume)
    described_class.call
    item.reload
  end

  def with_average_volume(volume)
    (1..50).each { |n| create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 24) - n, volume: volume) }
    create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 24), volume: 0)
  end

  it "leaves held stocks to the position (no entry alerts)" do
    item.update!(status: "holding")

    expect { move_to(505) }.not_to change(WatchlistAlert, :count)
    expect(item.status).to eq("holding")
  end

  it "does not alert while the state is unchanged" do
    expect { move_to(495) }.not_to change(WatchlistAlert, :count)
    expect(item.last_evaluated_at).to be_present
  end

  it "confirms a VCP breakout when volume is at least 1.5x the average" do
    with_average_volume(10_000)
    move_to(505, volume: 18_000)

    alert = item.alerts.last
    expect(alert.kind).to eq("breakout_confirmed")
    expect(alert.relative_volume.to_f).to eq(1.8)
    expect(alert.message).to eq("NABIL broke above the 500.00 pivot at 505.00 on 1.8x its 50-day average volume so far.")
    expect(item).to have_attributes(status: "in_zone", price_state: "in_zone", touched_zone_on: Nepse::MarketHours.today)
  end

  it "flags a breakout on light volume" do
    with_average_volume(10_000)
    move_to(505, volume: 9_000)

    expect(item.alerts.last.kind).to eq("breakout_low_volume")
    expect(item.alerts.last.message).to include("0.9x", "Wait for volume to confirm")
  end

  it "reports a pullback entering its zone" do
    item.update!(setup_type: "pullback", price_state: "extended", status: "extended")
    move_to(510)

    expect(item.alerts.last).to have_attributes(kind: "entered_zone", message: "NABIL is in its entry zone at 510.00 (500.00-515.00).")
  end

  it "warns when the price runs above the zone" do
    move_to(530)

    expect(item.alerts.last.kind).to eq("extended")
    expect(item.status).to eq("extended")
  end

  it "invalidates the setup and keeps it invalidated if the price recovers" do
    move_to(465)
    expect(item.alerts.last.kind).to eq("invalidated")
    expect(item.status).to eq("invalidated")

    move_to(505)
    expect(item.status).to eq("invalidated")
    expect(item.price_state).to eq("in_zone")
  end

  it "still alerts for planned items but keeps their status" do
    item.update!(status: "planned")
    move_to(530)

    expect(item.alerts.last.kind).to eq("extended")
    expect(item.status).to eq("planned")
  end

  it "ignores archived items" do
    item.update!(status: "archived")

    expect { move_to(530) }.not_to change(WatchlistAlert, :count)
  end

  it "records the starting state without alerting" do
    fresh = create(:watchlist_item, stock: create(:stock, last_price: 510.0))

    expect { described_class.initial_state!(fresh) }.not_to change(WatchlistAlert, :count)
    expect(fresh.reload).to have_attributes(price_state: "in_zone", status: "in_zone")
  end

  it "raises breakout alerts for a flat-base breakout too" do
    item.update!(setup_type: "base_breakout")
    with_average_volume(10_000)
    move_to(505, volume: 18_000)

    expect(item.alerts.last.kind).to eq("breakout_confirmed")
  end
end
