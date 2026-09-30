require "rails_helper"

RSpec.describe Backtest::Runner do
  let(:start) { Date.new(2026, 6, 1) }
  let(:days) { (0...40).map { start + _1 } }
  let(:nepse) { create(:market_index, symbol: "NEPSE") }

  before { days.each_with_index { |day, i| create(:market_index_history, market_index: nepse, traded_on: day, index_value: 2000 + i) } }

  # bars: array of [open, high, low, close]
  def stock_with(symbol, bars)
    stock = create(:stock, symbol: symbol)
    bars.each_with_index do |(open, high, low, close), i|
      create(:stock_daily_price, stock: stock, traded_on: days[i], open_price: open, high_price: high, low_price: low, close_price: close)
    end
    stock
  end

  def signal(stock, day_index, readiness: 70, in_zone: true, **levels)
    StockSetupSnapshot.create!(
      stock: stock, traded_on: days[day_index], close_price: 100, readiness_score: readiness, zone_state: "in_zone",
      in_buy_zone: in_zone, trend_rules_passed: 6, flow_state: "accumulation",
      entry_zone_low: 98, entry_zone_high: 103, invalidation_price: levels.fetch(:stop, 95), target_price: levels.fetch(:target, 110)
    )
  end

  def flat(n, price = 100.0) = Array.new(n) { [ price, price + 1, price - 1, price ] }

  it "exits at the target and computes return net of costs and the R multiple" do
    bars = flat(3) + [ [ 101, 104, 100, 103 ], [ 104, 111, 103, 110 ] ] + flat(35, 110)
    signal(stock_with("WIN", bars), 2)

    trade = described_class.call(save: false)[:trades][:list].sole

    expect(trade).to include(status: "closed", entry: 101.0, exit: 110.0, exit_reason: "target", sessions_held: 2)
    expect(trade[:return_pct]).to eq(((110.0 / 101 - 1 - 0.008) * 100).round(2))
    expect(trade[:r_multiple]).to eq(((110.0 - 101) / (101 - 95)).round(2))
  end

  it "counts a day that hits both stop and target as a stop, and exits a gap-down at the open" do
    both = flat(3) + [ [ 100, 112, 94, 105 ] ] + flat(36)
    gap = flat(3) + [ [ 100, 101, 99, 100 ], [ 90, 92, 89, 91 ] ] + flat(35, 91)
    signal(stock_with("BOTH", both), 2)
    signal(stock_with("GAP", gap), 2)

    trades = described_class.call(save: false)[:trades][:list].index_by { _1[:symbol] }

    expect(trades["BOTH"]).to include(exit_reason: "stop", exit: 95.0)
    expect(trades["GAP"]).to include(exit_reason: "stop", exit: 90.0) # gapped below the 95 stop
  end

  it "exits on time after 20 sessions and takes one trade per stock at a time" do
    stock = stock_with("SLOW", flat(40, 100.0))
    signal(stock, 2)
    signal(stock, 5) # while the first trade is open: ignored

    stats = described_class.call(save: false)[:trades]

    expect(stats[:total]).to eq(1)
    expect(stats[:list].sole).to include(exit_reason: "time", sessions_held: 20)
    expect(stats[:exits]).to eq("time" => 1)
  end

  it "leaves a trade open when the data runs out" do
    signal(stock_with("LATE", flat(40)), 30)

    expect(described_class.call(save: false)[:trades]).to include(total: 1, closed: 0, open: 1)
  end

  it "groups forward returns by readiness band and compares them with NEPSE" do
    rising = stock_with("UP", Array.new(40) { |i| p = 100.0 + i; [ p, p + 1, p - 1, p ] })
    signal(rising, 0, readiness: 75, in_zone: false)
    signal(rising, 1, readiness: 10, in_zone: false)

    result = described_class.call(save: false)
    high = result[:groups][:readiness]["60+"][5]

    expect(high).to include(n: 1, avg_return_pct: 5.0, win_rate_pct: 100.0)
    expect(high[:avg_excess_pct]).to eq(((105.0 / 100 - 2005.0 / 2000) * 100).round(2))
    expect(result[:groups][:readiness]["0-19"][5][:n]).to eq(1)
    expect(result[:baseline][20][:n]).to eq(2)
    expect(result[:period]).to include(sessions: 2, snapshots: 2, stocks: 1)
  end

  it "saves the run" do
    signal(stock_with("WIN", flat(40)), 2)

    expect { described_class.call }.to change(BacktestRun, :count).by(1)
    expect(BacktestRun.last).to have_attributes(sessions: 1, from_date: days[2])
    expect(BacktestRun.last.parameters).to include("max_hold" => 20, "round_trip_cost_pct" => 0.8)
  end

  it "ignores snapshots dated outside NEPSE sessions" do
    stock = stock_with("WIN", flat(40))
    StockSetupSnapshot.create!(stock: stock, traded_on: start - 1, close_price: 100, zone_state: "in_zone", in_buy_zone: true,
                               readiness_score: 70, invalidation_price: 95, target_price: 110)

    expect(described_class.call(save: false)).to include(success: false)
  end

  it "explains when there are no snapshots" do
    expect(described_class.call(save: false)).to include(success: false)
  end
end
