require "rails_helper"

RSpec.describe Setups::Guards do
  describe ".call" do
    it "flags thin turnover and either circuit" do
      expect(described_class.call(avg_turnover: 1_500_000, change_pct: 1.0)).to eq([ "thin_volume" ])
      expect(described_class.call(avg_turnover: 9_000_000, change_pct: 9.6)).to eq([ "upper_circuit" ])
      expect(described_class.call(avg_turnover: 1_000_000, change_pct: -10.0)).to eq(%w[thin_volume lower_circuit])
      expect(described_class.call(avg_turnover: 2_000_000, change_pct: 9.4)).to eq([])
      expect(described_class.call(avg_turnover: nil, change_pct: nil)).to eq([])
    end
  end

  describe "measurements" do
    let(:stock) { create(:stock) }
    let(:sessions) { (1..20).map { Date.new(2026, 9, 30) - _1 } } # newest first

    it "averages turnover over market sessions, counting untraded sessions as zero" do
      sessions.first(10).each { create(:stock_daily_price, stock: stock, traded_on: _1, turnover: 3_000_000) }

      expect(described_class.avg_turnover(stock.daily_prices, sessions)).to eq(1_500_000)
      expect(described_class.avg_turnover(stock.daily_prices, [])).to be_nil
    end

    it "falls back to volume x close when turnover is missing" do
      price = build(:stock_daily_price, turnover: 0, volume: 1_000, close_price: 250)

      expect(described_class.turnover(price)).to eq(250_000)
    end

    it "measures the close-to-close change up to the session only" do
      create(:stock_daily_price, stock: stock, traded_on: sessions[2], close_price: 100)
      create(:stock_daily_price, stock: stock, traded_on: sessions[1], close_price: 110)
      create(:stock_daily_price, stock: stock, traded_on: sessions[0], close_price: 99)

      expect(described_class.change_pct(stock.daily_prices, sessions[1])).to eq(10.0)
      expect(described_class.change_pct(stock.daily_prices, sessions[0])).to eq(-10.0)
      expect(described_class.change_pct(stock.daily_prices, sessions[2])).to be_nil
    end
  end
end
