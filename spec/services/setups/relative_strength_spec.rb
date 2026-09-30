require "rails_helper"

RSpec.describe Setups::RelativeStrength do
  it "weights the latest quarter double" do
    closes = Array.new(253) { 100.0 }
    closes[-1] = 120.0 # +20% over every period

    expect(described_class.score(closes)).to eq(1.2)
  end

  it "uses the oldest close when history is shorter than a period" do
    closes = Array.new(100) { |i| 100.0 + i } # 100..199
    # 63 sessions ago = 136; 126/189/252 fall back to the first close (100).
    expected = (0.4 * 199 / 136 + 0.6 * 199 / 100.0).round(4)

    expect(described_class.score(closes)).to eq(expected)
  end

  it "needs more than 63 sessions" do
    expect(described_class.score(Array.new(63) { 100 })).to be_nil
  end

  it "ranks scores into 1-99" do
    expect(described_class.ratings(a: 0.9, b: 1.1, c: 1.0, d: nil)).to eq(a: 1, c: 50, b: 99)
  end
end
