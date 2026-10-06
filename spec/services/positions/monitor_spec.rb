require "rails_helper"

RSpec.describe Positions::Monitor do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:stock) { create(:stock, symbol: "NABIL", last_price: 100) }
  # 100 shares at 100 on Thursday 2026-09-24; stop 92 (8 below), target 120.
  let!(:position) do
    user.positions.create!(stock: stock, stop_price: 92, initial_stop_price: 92, target_price: 120).tap do |p|
      p.fills.create!(side: "buy", price: 100, quantity: 100, traded_on: Date.new(2026, 9, 24))
    end
  end

  before { travel_to ActiveSupport::TimeZone["Asia/Kathmandu"].parse("2026-09-24 13:00") }
  after { travel_back }

  def price!(value)
    stock.update!(last_price: value)
    described_class.call
    position.alerts.reload.order(:id)
  end

  describe "live rules" do
    it "alerts once when the stop is hit, noting T+2 settlement" do
      alerts = price!(91.5)

      expect(alerts.map(&:kind)).to eq([ "stop_hit" ])
      expect(alerts.last.message).to start_with("NABIL is at 91.50, at or below your 92.00 stop. Selling at the stop: -Rs ")
      expect(alerts.last.message).to end_with("The shares bought 24 Sep settle (T+2) and can be sold from 28 Sep.")
      expect { price!(91.0) }.not_to change(PositionAlert, :count)
    end

    it "alerts again for a new stop level" do
      price!(91.5)
      position.update!(stop_price: 90)

      expect { price!(89.5) }.to change(PositionAlert, :count).by(1)
    end

    it "reports +1R while the stop is below break-even, the +20% zone and the target" do
      expect(price!(108.5).map(&:kind)).to eq([ "one_r" ])
      expect(position.alerts.last.message).to include("is up 1R at 108.50 (1.06R)", "moving it to break-even (")

      expect(price!(121).map(&:kind)).to eq(%w[one_r target_reached profit_zone])
      expect(position.alerts.find_by(kind: "profit_zone").message).to eq(
        "NABIL is +21.0% above your 100.00 average: the 20-25% zone where O'Neil-style traders take some profit."
      )
    end

    it "skips +1R once the stop is at break-even" do
      position.update!(stop_price: 101)

      expect(price!(109).map(&:kind)).to be_empty
    end

    it "ignores closed positions" do
      position.update!(status: "closed")

      expect(price!(80)).to be_empty
    end
  end

  describe "close rules" do
    # 60 sessions ending 2026-09-24, on 1,000 shares a day with a 2% range.
    def history(closes, volumes: {}, sma_50: {}, avg_volume_50: 1_000)
      dates = (1..closes.size).map { |n| Date.new(2026, 9, 24) - (closes.size - n) }
      dates.each_with_index do |day, i|
        price = create(:stock_daily_price, stock: stock, traded_on: day, close_price: closes[i], high_price: closes[i] * 1.01,
                                           low_price: closes[i] * 0.99, volume: volumes.fetch(i, 1_000))
        StockDailyIndicator.create!(stock: stock, stock_daily_price: price, traded_on: day, sma_50: sma_50.fetch(i, closes[i] * 0.95), avg_volume_50: avg_volume_50)
      end
    end

    it "alerts on a close below the 50-day from above it, on above-average volume" do
      history([ 100.0 ] * 59 + [ 97.0 ], volumes: { 59 => 1_800 }, sma_50: { 58 => 98.0, 59 => 98.5 })
      stock.update!(last_price: 97)

      described_class.call(close: true)

      expect(position.alerts.sole).to have_attributes(kind: "fifty_day_break", key: "2026-09-24")
      expect(position.alerts.sole.message).to eq(
        "NABIL closed at 97.00, below its 50-day average (98.50) on 1.8x average volume: a common sell signal for swing trades."
      )
    end

    it "alerts on a climax run: a 3+ ADR jump on the heaviest volume, far above the 50-day" do
      history(Array.new(59) { 120.0 + _1 } + [ 190.0 ], volumes: { 59 => 5_000 }, sma_50: { 59 => 140.0 })
      stock.update!(last_price: 190)

      described_class.call(close: true)

      # 178 -> 190 is +6.7%, 3.3 times the 2.0% average daily range; 190 is 36% above 140.
      expect(position.alerts.find_by(kind: "climax_run").message).to eq(
        "NABIL jumped +6.7% (3.3 ADR) on its heaviest volume in 50 sessions, 36% above its 50-day: climax runs often mark a top."
      )
    end

    it "flags a time stop after 15 sessions under 0.5R" do
      position.fills.first.update!(traded_on: Date.new(2026, 8, 20))
      history([ 100.0 ] * 60)
      stock.update!(last_price: 101)

      described_class.call(close: true)

      expect(position.alerts.sole.message).to match(/\ANABIL has gone \d+ sessions at 0.13R \(under 0.5R\)/)
    end
  end
end
