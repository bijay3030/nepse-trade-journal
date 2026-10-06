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

  it "leaves held stocks to the position (no entry alerts)" do
    item.update!(status: "holding")

    expect { move_to(505) }.not_to change(WatchlistAlert, :count)
    expect(item.status).to eq("holding")
  end

  it "does not alert while the state is unchanged" do
    expect { move_to(480) }.not_to change(WatchlistAlert, :count)
    expect(item.last_evaluated_at).to be_present
  end

  describe "breakout volume, projected to the close" do
    include ActiveSupport::Testing::TimeHelpers

    # Thursday 2026-09-24; 50 earlier sessions averaging 10,000 shares.
    def at(npt_time) = travel_to(ActiveSupport::TimeZone["Asia/Kathmandu"].parse("2026-09-24 #{npt_time}"))

    before do
      (1..50).each { |n| create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 24) - n, volume: 10_000) }
    end

    after { travel_back }

    it "confirms a breakout whose projected volume is at least 1.5x the average" do
      at("14:00") # default curve: 76% of the day's volume by 3 hours in
      move_to(505, volume: 18_000)

      alert = item.alerts.last
      expect(alert.kind).to eq("breakout_confirmed")
      expect(alert.relative_volume.to_f).to eq(2.37)
      expect(alert.message).to eq("NABIL broke above the 500.00 pivot at 505.00 on a projected 2.37x its 50-day average volume (18,000 so far by 2:00).")
      expect(item).to have_attributes(status: "in_zone", price_state: "in_zone", touched_zone_on: Date.new(2026, 9, 24))
    end

    it "doesn't call an early breakout light just because the day has barely started" do
      at("11:30") # 22% of the day traded: 4,000 so far projects to ~18,000
      move_to(505, volume: 4_000)

      expect(item.alerts.last).to have_attributes(kind: "breakout_confirmed", relative_volume: 1.82)
    end

    it "flags light projected volume, and says when it's too early to judge" do
      at("14:00")
      move_to(505, volume: 9_000)
      expect(item.alerts.last.kind).to eq("breakout_low_volume")
      expect(item.alerts.last.message).to include("projected 1.18x", "Wait for volume to confirm")

      item.update!(price_state: "below_zone")
      at("11:05")
      move_to(506, volume: 500)
      expect(item.alerts.last.message).to eq("NABIL broke above the 500.00 pivot at 506.00. It's too early in the session to judge volume; the close will confirm or reject it.")
    end

    it "raises breakout alerts for a flat-base breakout too" do
      at("14:00")
      item.update!(setup_type: "base_breakout")
      move_to(505, volume: 18_000)

      expect(item.alerts.last.kind).to eq("breakout_confirmed")
    end

    it "uses the day's total after the close, and notes an upper-circuit lock" do
      at("15:30")
      stock.update!(change_percent: 14.8)
      move_to(505, volume: 12_000)

      expect(item.alerts.last.message).to eq(
        "NABIL broke above the 500.00 pivot at 505.00, but on 1.2x its 50-day average volume (below 1.5x). Wait for volume to confirm. " \
        "It's at the upper circuit, so volume understates demand."
      )
    end
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

  describe "approaching the zone" do
    it "alerts once within 3% below the pivot, and again only after moving 5% away" do
      expect { move_to(488) }.to change(WatchlistAlert, :count).by(1)
      expect(item.alerts.last).to have_attributes(kind: "approaching_zone", message: "NABIL is 2.5% below its 500.00 pivot at 488.00.")
      expect(item.approach_alerted).to be(true)

      expect { move_to(492) }.not_to change(WatchlistAlert, :count)
      move_to(475) # 5.3% away
      expect(item.approach_alerted).to be(false)
      expect { move_to(491) }.to change { item.alerts.where(kind: "approaching_zone").count }.by(1)
    end

    it "names the zone for a pullback setup" do
      item.update!(setup_type: "ma_pullback", pivot_price: nil)
      move_to(490)

      expect(item.alerts.last.message).to eq("NABIL is 2.0% below its entry zone (500.00-515.00) at 490.00.")
    end
  end

  describe "pullback to the rising 21-day average" do
    include ActiveSupport::Testing::TimeHelpers

    # 60 sessions rising 2 a day to 458 on 10,000 shares; the 21-day EMA lags about 4% below.
    let(:closes) { Array.new(60) { 340.0 + _1 * 2 } }
    let(:ema) { Setups::MovingAverage.ema_series(closes, 21).last }

    before do
      travel_to ActiveSupport::TimeZone["Asia/Kathmandu"].parse("2026-09-24 14:00")
      closes.each_with_index { |close, i| create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 24) - (60 - i), close_price: close, volume: 10_000) }
      item.update!(setup_type: "ma_pullback", entry_zone_low: 520, entry_zone_high: 530, invalidation_price: 400, pivot_price: nil)
      Rails.cache.clear
    end

    after { travel_back }

    it "alerts when the price reaches the rising EMA on lighter projected volume, once a day" do
      expect { move_to((ema * 1.005).round(2), volume: 5_000) }.to change(WatchlistAlert, :count).by(1)
      expect(item.alerts.last.kind).to eq("pullback_21ema")
      expect(item.alerts.last.message).to match(/\ANABIL pulled back to its rising 21-day average \(#{format('%.2f', ema)}\) at [\d.]+ on lighter volume \(projected 0.66x\)\.\z/)

      expect { move_to((ema * 1.002).round(2), volume: 5_500) }.not_to change(WatchlistAlert, :count)
    end

    it "stays quiet on heavy volume or away from the average" do
      expect { move_to((ema * 1.005).round(2), volume: 9_000) }.not_to change(WatchlistAlert, :count)
      expect { move_to((ema * 1.03).round(2), volume: 5_000) }.not_to change(WatchlistAlert, :count)
    end
  end
end
