require "rails_helper"

RSpec.describe Nepse::MarketHours do
  def npt(string)
    ActiveSupport::TimeZone["Asia/Kathmandu"].parse(string)
  end

  it "is open during trading hours on a trading day" do
    expect(described_class.open?(npt("2026-09-27 11:00"))).to be(true) # Sunday
    expect(described_class.open?(npt("2026-10-01 14:59"))).to be(true) # Thursday
  end

  it "is closed before the open, after the close, and on Friday and Saturday" do
    expect(described_class.open?(npt("2026-09-27 10:59"))).to be(false)
    expect(described_class.open?(npt("2026-09-27 15:00"))).to be(false)
    expect(described_class.open?(npt("2026-10-02 12:00"))).to be(false) # Friday
    expect(described_class.open?(npt("2026-10-03 12:00"))).to be(false) # Saturday
  end

  it "keeps the sync window open briefly after the close" do
    expect(described_class.sync_window?(npt("2026-09-27 15:10"))).to be(true)
    expect(described_class.sync_window?(npt("2026-09-27 15:15"))).to be(false)
  end

  it "evaluates times given in other zones in Nepal time" do
    expect(described_class.open?(Time.utc(2026, 9, 27, 5, 15))).to be(true)  # 11:00 NPT
    expect(described_class.open?(Time.utc(2026, 9, 27, 5, 14))).to be(false) # 10:59 NPT
  end
end
