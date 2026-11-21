require "rails_helper"

RSpec.describe Lab::Backtest do
  def trades(returns, from: Date.new(2023, 1, 1))
    returns.each_with_index.map { |r, i| { return_pct: r, r: r / 5.0, entry_on: from + i * 30 } }
  end

  it "summarises trades with profit factor and compounded drawdown, plus the out-of-sample part" do
    record = described_class.stats(trades([ 10, -5, 10, -5 ]) + trades([ 4, -2, 3 ], from: Date.new(2025, 3, 1)))
    expect(record).to include(trades: 7, win_rate_pct: 57.1, profit_factor: 2.25)
    expect(record[:max_drawdown_pct]).to eq(-5.0)
    expect(record[:oos]).to include(trades: 3, avg_return_pct: 1.67)
  end

  it "qualifies a stock only with enough trades, a profit factor above 1.3 and a positive recent record" do
    good = described_class.stats(trades([ 6, -3 ] * 4) + trades([ 5, -2, 4 ], from: Date.new(2025, 2, 1)))
    expect(described_class.qualifies?(good)).to be(true)
    expect(described_class.qualifies?(described_class.stats(trades([ 6, -3 ] * 3)))).to be(false) # too few, no recent trades
    stale = described_class.stats(trades([ 6, -3 ] * 5) + trades([ -2, -2, 1 ], from: Date.new(2025, 2, 1)))
    expect(described_class.qualifies?(stale)).to be(false) # stopped working
  end
end
