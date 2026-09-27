require "rails_helper"

RSpec.describe Nepse::DailyPriceImporterService do
  let(:traded_on) { Date.new(2026, 9, 27) }
  let!(:stock) { create(:stock, symbol: "NABIL", last_price: 500.0, change_percent: 1.0, volume: 12_000) }
  let(:ltp_only_quote) { { symbol: "NABIL", last_price: 550.0, change_percent: nil, volume: nil, total_trades: nil } }

  before do
    create(:stock_daily_price, stock: stock, traded_on: traded_on - 1, close_price: 500.0)
    allow(NepsePriceService).to receive(:new).with("NABIL").and_return(instance_double(NepsePriceService, fetch_current: ltp_only_quote))
  end

  it "computes change from the previous close and keeps the stored volume when the API only returns a price" do
    result = described_class.call(traded_on)

    expect(result).to include(success: true, processed: 1)
    stock.reload
    expect(stock.last_price.to_f).to eq(550.0)
    expect(stock.change_percent.to_f).to eq(10.0)
    expect(stock.volume).to eq(12_000)
  end

  it "records a new day without inventing a zero low" do
    described_class.call(traded_on)

    daily = StockDailyPrice.find_by!(stock: stock, traded_on: traded_on)
    expect(daily).to have_attributes(open_price: 550.0, high_price: 550.0, low_price: 550.0, close_price: 550.0, previous_close: 500.0)
    expect(daily.change_percent.to_f).to eq(10.0)
  end

  it "does not overwrite real values already recorded for the day" do
    create(
      :stock_daily_price, stock: stock, traded_on: traded_on,
      open_price: 505.0, high_price: 560.0, low_price: 498.0, close_price: 540.0,
      previous_close: 500.0, volume: 30_000, turnover: 16_000_000.0, total_trades: 250
    )

    described_class.call(traded_on)

    daily = StockDailyPrice.find_by!(stock: stock, traded_on: traded_on)
    expect(daily).to have_attributes(open_price: 505.0, high_price: 560.0, low_price: 498.0, close_price: 550.0, volume: 30_000, total_trades: 250)
    expect(daily.turnover.to_f).to eq(16_000_000.0)
  end
end
