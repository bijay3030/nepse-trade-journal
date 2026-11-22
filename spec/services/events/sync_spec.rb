require "rails_helper"

RSpec.describe Events::Sync do
  let(:today) { Date.new(2026, 11, 22) }
  let!(:nabil) { create(:stock, symbol: "NABIL", name: "Nabil Bank Limited", security_type: "Equity") }
  let!(:nica) { create(:stock, symbol: "NICA", name: "NIC Asia Bank Limited", security_type: "Equity") }
  let(:item) { ->(title, date = today) { { title: title, url: "https://www.sharesansar.com/announcementdetail/#{title.parameterize}-#{date}", published_on: date } } }
  let(:announcements) { instance_double(Nepse::Source::SharesansarAnnouncementsClient) }
  let(:chukul) do
    instance_double(Nepse::Source::ChukulClient,
                    bonus_feed: { success: true, data: [
                      { "symbol" => "NABIL", "year" => "082/083", "bonus" => 12.0, "cash" => 3.0, "annoucement_date" => "2026-11-20", "book_close_date" => "2026-12-04" },
                      { "symbol" => "NABIL", "year" => "077/078", "bonus" => 5.0, "cash" => 0, "annoucement_date" => "2021-11-20", "book_close_date" => "2021-12-04" },
                      { "symbol" => "NICA", "year" => "081/082", "bonus" => 0, "cash" => 0, "annoucement_date" => "2026-12-24" } # dated in the future: an error
                    ] },
                    rights_feed: { success: true, data: [ { "symbol" => "NICA", "year" => "083/84", "right" => 50.0, "book_close_date" => "2026-11-27" } ] })
  end

  it "stores rated announcements and Chukul's dividend and rights events, once" do
    allow(announcements).to receive(:page).with(cursor: nil).and_return(success: true, next_cursor: "c2", items: [
      item.("Nabil Bank Limited has posted a net profit of Rs 1,200 million and published its 1st quarter company analysis of the fiscal year 2083/84."),
      item.("Orbit Energy Limited has announced its 3rd AGM going to be held on 23rd Mangsir, 2083.")
    ])
    allow(announcements).to receive(:page).with(cursor: "c2").and_return(success: true, next_cursor: nil, items: [])

    result = described_class.call(today: today, announcements: announcements, chukul: chukul)

    expect(result).to eq(announcements: { created: 2 }, dividends: { events: 1 }, rights: { events: 1 })
    expect(MarketEvent.find_by(kind: "results")).to have_attributes(stock_id: nabil.id, impact: "neutral", published_on: today)
    expect(MarketEvent.find_by(kind: "agm")).to have_attributes(stock_id: nil)
    expect(MarketEvent.find_by(kind: "bonus")).to have_attributes(stock_id: nabil.id, impact: "positive", event_on: Date.new(2026, 12, 4), important: true,
                                                                  title: "NABIL: 12% bonus + 3% cash dividend for 082/083, book close 4 Dec 2026")
    expect(MarketEvent.find_by(kind: "rights")).to have_attributes(stock_id: nica.id, impact: "mixed", event_on: Date.new(2026, 11, 27))

    expect(described_class.call(today: today, announcements: announcements, chukul: chukul)[:announcements]).to eq(created: 0)
    expect(MarketEvent.count).to eq(4)
  end

  it "compares a result with the same quarter of the year before" do
    MarketEvent.create!(stock: nabil, source: "sharesansar", external_id: "old", kind: "results", impact: "neutral", title: "old", published_on: Date.new(2025, 11, 20),
                        data: { "net_profit_m" => 1000.0, "quarter" => 1, "fiscal_year" => "2082/83" })
    allow(announcements).to receive(:page).and_return(success: true, next_cursor: nil, items: [
      item.("Nabil Bank Limited has posted a net profit of Rs 1,200 million and published its 1st quarter company analysis of the fiscal year 2083/84.")
    ])

    described_class.call(today: today, announcements: announcements, chukul: chukul)
    expect(MarketEvent.where(kind: "results").order(:id).last).to have_attributes(impact: "positive", reason: include("up from Rs 1000M (+20.0%)"))
  end
end
