require "rails_helper"

RSpec.describe Setups::MarketDirection do
  # Builds [[date, close, turnover], ...] from daily percent changes; turnover rises on
  # the days marked heavy (true) and falls otherwise.
  def series(changes, heavy: [])
    close = 1000.0
    turnover = 100.0
    changes.each_with_index.map do |change, i|
      close *= 1 + change / 100.0
      turnover = heavy.include?(i) ? turnover * 1.2 : turnover * 0.9
      [ Date.new(2026, 1, 1) + i, close.round(2), turnover.round(2) ]
    end
  end

  def states(data, **options) = described_class.timeline(data, **options).values

  it "counts distribution days (down 0.5%+ on higher turnover) and goes under pressure at four" do
    changes = [ 0.3 ] * 5 + [ -0.6, 0.2, -0.6, 0.2, -0.6, 0.2, -0.6, 0.2 ]
    result = states(series(changes, heavy: [ 5, 7, 9, 11 ]))

    expect(result[9]).to include(state: "uptrend", distribution_days: 3)
    expect(result[11]).to include(state: "under_pressure", distribution_days: 4)
  end

  it "ignores down days on lower turnover, and IBD's 0.2% threshold counts smaller drops" do
    data = series([ 0.3, -0.3, 0.1, -0.3 ], heavy: [ 1, 3 ])

    expect(states(data).last[:distribution_days]).to eq(0)
    expect(states(data, down_pct: 0.2, up_pct: 1.2).last[:distribution_days]).to eq(2)
    expect(states(series([ 0.3, -0.8 ])).last[:distribution_days]).to eq(0) # lighter turnover
  end

  it "expires a distribution day after 25 sessions" do
    data = series([ 0.1, -0.6 ] + [ 0.0 ] * 25, heavy: [ 1 ])

    expect(states(data)[25][:distribution_days]).to eq(1)
    expect(states(data)[26][:distribution_days]).to eq(0)
  end

  it "calls a correction after a 10% fall and ends it with a follow-through day" do
    fall = [ 0.2 ] + [ -2.0 ] * 6               # about 11% down
    attempt = [ 0.5, 0.3, 0.2 ]                 # rally days 1-3
    follow_through = [ 1.8 ]                    # day 4, up 1.8% on higher turnover
    data = series(fall + attempt + follow_through, heavy: [ 10 ])
    result = states(data)

    expect(result[6]).to include(state: "correction")
    expect(result[9]).to include(state: "correction", rally_day: 3)
    expect(result[10]).to include(state: "uptrend", follow_through_on: Date.new(2026, 1, 11), distribution_days: 0)
  end

  it "restarts the rally attempt when the index undercuts its low, and needs day 4 or later" do
    data = series([ 0.2 ] + [ -2.0 ] * 6 + [ 1.8, -2.5, 0.4, 0.3, 0.2, 1.6 ], heavy: [ 7, 12 ])
    result = states(data)

    expect(result[7]).to include(state: "correction", rally_day: 1) # big up day too early
    expect(result[8]).to include(state: "correction", rally_day: 0) # new low
    expect(result[12]).to include(state: "uptrend")
  end

  it "reports the latest state with its label and size factor" do
    index = MarketIndex.create!(symbol: "NEPSE", name: "NEPSE Index")
    series([ 0.2 ] + [ -2.0 ] * 6).each { |date, close, turnover| index.histories.create!(traded_on: date, index_value: close, turnover: turnover) }

    expect(described_class.call).to include(state: "correction", label: "Correction", size_factor: 0.25, threshold_set: "nepse")
  end
end
