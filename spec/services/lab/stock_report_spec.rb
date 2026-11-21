require "rails_helper"

RSpec.describe Lab::StockReport do
  let(:stock) { create(:stock, symbol: "WAVE", security_type: "Equity") }

  before do
    # A rising wave: crosses up and down every few weeks.
    (0...260).each do |i|
      close = 100 + i * 0.2 + 12 * Math.sin(i / 8.0)
      create(:stock_daily_price, stock: stock, traded_on: Date.new(2025, 1, 1) + i, open_price: close - 0.3, high_price: close + 1.5,
                                 low_price: close - 1.5, close_price: close, previous_close: close, volume: 10_000 + (i % 7) * 5_000)
    end
  end

  it "backtests every strategy on the stock and reports buy and hold" do
    report = described_class.call(stock)

    expect(report).to include(symbol: "WAVE", sessions: 260, from: Date.new(2025, 1, 1))
    keys = report[:strategies].map { _1[:key] }
    expect(keys).to include("scan_ema_9_21", "scan_hma_up_vol", "macd_cross", "bollinger_bounce", "breakout_20d", "golden_cross", "lab_rsi_reversion")
    expect(report[:strategies].find { _1[:key] == "scan_hma_up_vol" }[:label]).to eq("HMA 55 turns up on 1.5× volume")

    macd = report[:strategies].find { _1[:key] == "macd_cross" }
    expect(macd[:signals]).to be_positive
    expect(macd[:stats][:trades]).to be_positive
    expect(macd[:stats]).to include(:win_rate_pct, :profit_factor, :total_return_pct, :by_year)
    expect(report[:trades].select { _1[:key] == "macd_cross" && !_1[:open] }.size).to eq(macd[:stats][:trades])
    first = report[:trades].find { _1[:key] == "macd_cross" && !_1[:open] }
    expect(first[:signal_on]).to eq(first[:entry_on] - 1) # bought at the open after the signal session
    expect(first[:held_days]).to eq((first[:exit_on] - first[:entry_on]).to_i)
    expect(first[:held_sessions]).to be_between(1, 20)
    expect(%w[stop target time]).to include(first[:reason])

    ranked = report[:strategies].select { _1[:stats][:trades].positive? && _1[:stats][:profit_factor] }.map { _1[:stats][:profit_factor] }
    expect(ranked).to eq(ranked.sort.reverse)
    expect(report[:buy_hold][:return_pct]).to be_positive
    expect(report[:prices].size).to eq(260)
  end

  it "takes a trade at the next open with a stop under the 10-session low and a 2x target, net of costs" do
    x = { dates: (0..3).map { Date.new(2025, 1, 1) + _1 }, open: [ 100, 101, 104, 106 ], high: [ 101, 103, 106, 115 ],
          low: [ 96, 100, 103, 105 ], close: [ 100, 102, 105, 110 ] }
    trade = described_class.simulate(x, 0)
    stop = 96 * 0.99
    expect(trade).to include(entry_index: 1, entry: 101, reason: "target", exit: (101 + 2 * (101 - stop)))
    expect(trade[:return_pct]).to be_within(0.01).of(((101 + 2 * (101 - stop)) / 101.0 - 1) * 100 - 0.8)
    expect(described_class.simulate(x.merge(open: [ 100, 104, 104, 106 ]), 0)).to be_nil # opened more than 3% above the close
  end

  it "says when there isn't enough history" do
    short = create(:stock, symbol: "NEWL", security_type: "Equity")
    create(:stock_daily_price, stock: short, traded_on: Date.new(2026, 11, 1))
    expect(described_class.call(short)).to include(error: /Not enough price history/)
  end
end
