require "rails_helper"

RSpec.describe Indicators::Trend do
  let(:line) { (1..30).map(&:to_f) }

  it "computes EMA, WMA, Hull and ALMA like TradingView" do
    expect(described_class.ema(line, 9).first(8)).to all(be_nil)
    expect(described_class.ema(line, 9)[8]).to eq(5.0) # seeded with the simple average of 1..9
    expect(described_class.ema(line, 9).last).to be_within(1e-9).of(26.0) # lags (n-1)/2 bars on a straight line
    expect(described_class.wma(line, 5).last).to be_within(1e-4).of(28.6667)
    expect(described_class.hma(line, 9).last).to be_within(1e-9).of(30.0) # Hull removes the lag on a line
    expect(described_class.alma(line, 9).last).to be_within(0.01).of(28.44)
  end

  it "measures Aroon from the bars since the highest high and lowest low" do
    highs = [ 10, 12, 11, 15, 14, 13, 12 ].map(&:to_f)
    lows = [ 9, 8, 10, 12, 11, 10, 11 ].map(&:to_f)
    aroon = described_class.aroon(highs, lows, 4)

    # Last 5 bars: highest high 15 three bars ago, lowest low 10 one bar ago.
    expect(aroon[:up].last).to eq(25.0)
    expect(aroon[:down].last).to eq(75.0)
  end
end
