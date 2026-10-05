require "rails_helper"

RSpec.describe Nepse::VolumeProfile do
  include ActiveSupport::Testing::TimeHelpers

  let(:zone) { ActiveSupport::TimeZone["Asia/Kathmandu"] }

  after { travel_back }

  it "knows the minute of the session" do
    expect(described_class.session_minute(zone.parse("2026-09-24 11:45"))).to eq(45)
    expect(described_class.session_minute(zone.parse("2026-09-24 10:59"))).to be_nil
    expect(described_class.session_minute(zone.parse("2026-09-26 12:00"))).to be_nil # Saturday
  end

  it "interpolates the share of the day's volume and projects to the close" do
    points = described_class::DEFAULT_CURVE
    expect(described_class.share_at(45, points)).to be_within(0.001).of(0.285)
    expect(described_class.share_at(240, points)).to eq(1.0)

    travel_to zone.parse("2026-09-24 12:00") # 60 minutes in: 35% traded by default
    expect(described_class.projected(35_000)).to be_within(1).of(100_000)
    travel_to zone.parse("2026-09-24 11:10")
    expect(described_class.projected(5_000)).to be_nil
    travel_to zone.parse("2026-09-24 16:00")
    expect(described_class.projected(80_000)).to eq(80_000.0)
  end

  it "records running volumes during the session only, and drops old samples" do
    stock = create(:stock, volume: 12_000)
    create(:stock, volume: 0)
    StockIntradayVolume.create!(stock: stock, traded_on: Date.new(2026, 7, 1), minute: 30, volume: 1)

    expect(described_class.record!(zone.parse("2026-09-24 12:30"))).to eq(1)
    expect(described_class.record!(zone.parse("2026-09-24 12:30"))).to eq(1) # same moment: updated, not duplicated
    expect(described_class.record!(zone.parse("2026-09-24 16:00"))).to eq(0)
    expect(StockIntradayVolume.pluck(:traded_on, :minute, :volume)).to eq([ [ Date.new(2026, 9, 24), 90, 12_000 ] ])
  end

  it "learns NEPSE's own curve once there are enough sessions, ignoring stale volumes" do
    travel_to zone.parse("2026-10-01 10:00")
    stocks = Array.new(31) { create(:stock) }
    days = (1..6).map { Date.new(2026, 9, 23) + _1 }.reject { _1.saturday? || _1.sunday? }
    days = (days + [ Date.new(2026, 9, 21), Date.new(2026, 9, 22) ]).sort.first(5)
    days.each do |day|
      stocks.each do |stock|
        create(:stock_daily_price, stock: stock, traded_on: day, volume: 1_000)
        { 0 => 100, 30 => 400, 60 => 500, 120 => 700, 180 => 900 }.each do |minute, volume|
          StockIntradayVolume.create!(stock: stock, traded_on: day, minute: minute, volume: volume)
        end
        StockIntradayVolume.create!(stock: stock, traded_on: day, minute: 5, volume: 50_000) # yesterday's volume, not reset yet
      end
    end

    curve = described_class.build
    expect(curve).to include(source: "learned", sessions: 5)
    expect(curve[:points]).to eq([ [ 0, 0.0 ], [ 7, 0.1 ], [ 37, 0.4 ], [ 67, 0.5 ], [ 127, 0.7 ], [ 187, 0.9 ], [ 240, 1.0 ] ])
  end

  it "uses the default curve until there are enough sessions" do
    expect(described_class.build).to include(source: "default", points: described_class::DEFAULT_CURVE)
  end
end

RSpec.describe Nepse::VolumeProfile, ".pace" do
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  it "reports today's volume so far, the projection and its ratio to the 50-session average during the session" do
    now = ActiveSupport::TimeZone["Asia/Kathmandu"].parse("2026-09-24 12:00")
    travel_to now
    stock = create(:stock, volume: 35_000, last_updated: now)
    (1..10).each { create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 24) - _1, volume: 50_000) }

    expect(described_class.pace(stock)).to eq(so_far: 35_000, minute: 60, average: 50_000, projected: 100_000, ratio: 2.0,
                                              curve: { source: "default", sessions: 0 })

    stock.update!(last_updated: now - 1.day) # yesterday's volume
    expect(described_class.pace(stock)).to be_nil
  end
end
