require "rails_helper"

RSpec.describe Watchlist::CloseEvaluator do
  let(:session_day) { Date.new(2026, 9, 30) }
  let(:stock) { create(:stock, symbol: "NABIL") }
  # Zone 500-515, invalidation 470, pivot 500.
  let!(:item) { create(:watchlist_item, stock: stock) }

  before do
    (1..50).each { |n| create(:stock_daily_price, stock: stock, traded_on: session_day - n, volume: 10_000) }
  end

  def close_at(price, volume:)
    create(:stock_daily_price, stock: stock, traded_on: session_day, close_price: price, volume: volume)
    described_class.call
    item.reload
  end

  it "confirms a VCP breakout that closes in the zone on heavy volume" do
    close_at(508, volume: 18_000)

    expect(item).to have_attributes(last_close_on: session_day, last_close_state: "confirmed", last_close_price: 508, last_close_relative_volume: 1.8)
    expect(item.alerts.last).to have_attributes(kind: "close_confirmed", message: "NABIL closed at 508.00, above the 500.00 pivot, on 1.8x its 50-day average volume. Breakout confirmed at the close.")
  end

  it "flags a close above the pivot on light volume as unconfirmed" do
    close_at(508, volume: 9_000)

    expect(item.last_close_state).to eq("unconfirmed")
    expect(item.alerts.last.kind).to eq("close_unconfirmed")
  end

  it "calls a breakout failed when the zone was reached but the close fell back below it" do
    item.update!(touched_zone_on: session_day)
    close_at(495, volume: 20_000)

    expect(item.last_close_state).to eq("failed")
    expect(item.alerts.last.kind).to eq("close_failed")
  end

  it "records a quiet close below the zone without alerting" do
    expect { close_at(495, volume: 5_000) }.not_to change(WatchlistAlert, :count)
    expect(item.reload.last_close_state).to eq("below_zone")
  end

  it "reports a pullback holding its zone at the close" do
    item.update!(setup_type: "pullback")
    close_at(505, volume: 7_000)

    expect(item.alerts.last).to have_attributes(kind: "close_in_zone")
    expect(item.last_close_state).to eq("held_zone")
  end

  it "judges each session only once" do
    close_at(508, volume: 18_000)

    expect { described_class.call }.not_to change(WatchlistAlert, :count)
  end
end
