require "rails_helper"

RSpec.describe Nepse::MarketHours do
  def npt(string)
    ActiveSupport::TimeZone["Asia/Kathmandu"].parse(string)
  end

  it "is open during trading hours Monday to Friday" do
    expect(described_class.open?(npt("2026-09-28 11:00"))).to be(true) # Monday
    expect(described_class.open?(npt("2026-10-02 14:59"))).to be(true) # Friday
  end

  it "is closed before the open, after the close, and at the weekend" do
    expect(described_class.open?(npt("2026-09-28 10:59"))).to be(false)
    expect(described_class.open?(npt("2026-09-28 15:00"))).to be(false)
    expect(described_class.open?(npt("2026-10-03 12:00"))).to be(false) # Saturday
    expect(described_class.open?(npt("2026-09-27 12:00"))).to be(false) # Sunday
  end

  it "keeps the sync window open briefly after the close" do
    expect(described_class.sync_window?(npt("2026-09-28 15:10"))).to be(true)
    expect(described_class.sync_window?(npt("2026-09-28 15:15"))).to be(false)
  end

  it "evaluates times given in other zones in Nepal time" do
    expect(described_class.open?(Time.utc(2026, 9, 28, 5, 15))).to be(true)  # 11:00 NPT
    expect(described_class.open?(Time.utc(2026, 9, 28, 5, 14))).to be(false) # 10:59 NPT
  end

  it "uses NEPSE_TRADING_DAYS when set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("NEPSE_TRADING_DAYS").and_return("0,1,2,3,4")

    expect(described_class.open?(npt("2026-09-27 12:00"))).to be(true)  # Sunday
    expect(described_class.open?(npt("2026-10-02 12:00"))).to be(false) # Friday
  end
end
