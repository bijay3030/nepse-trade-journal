require "rails_helper"

RSpec.describe CorporateActions::WatchlistUpdater do
  let(:today) { Date.new(2026, 10, 5) }
  let(:stock) { create(:stock, symbol: "SBL") }
  # Zone 500-515, invalidation/stop 470, target 560, pivot 500; added before the book close.
  let!(:item) { create(:watchlist_item, stock: stock, price_at_add: 505, created_at: Date.new(2026, 9, 20)) }

  it "warns once before a book close" do
    stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, cash_percent: 5, book_close_on: today + 3, source: "chukul")

    expect(described_class.call(on: today)).to include(warned: 1)
    expect(described_class.call(on: today + 1)).to include(warned: 0)
    expect(item.alerts.sole).to have_attributes(kind: "book_close_soon", message: "SBL book close on Oct 8 (FY 082/083, 10.0% bonus and 5.0% cash). The price will be adjusted for the bonus; your levels will be adjusted to match.")
  end

  it "divides the levels by (1 + bonus) once the bonus book close has passed, only once" do
    stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: today - 1, source: "chukul")

    expect(described_class.call(on: today)).to include(adjusted: 1)
    expect(described_class.call(on: today)).to include(adjusted: 0)

    item.reload
    expect(item).to have_attributes(entry_zone_low: 454.55, entry_zone_high: 468.18, invalidation_price: 427.27, stop_loss_price: 427.27, target_price: 509.09, pivot_price: 454.55, price_at_add: 459.09)
    expect(item.level_adjustments.sole).to include("fiscal_year" => "082/083", "bonus_percent" => 10.0, "book_close_on" => (today - 1).iso8601)
    expect(item.alerts.find_by!(kind: "levels_adjusted").message).to eq("SBL levels adjusted for the 10.0% bonus (book close Oct 4): zone now 454.55-468.18, invalidation 427.27.")
  end

  it "ignores bonuses before the item was added and cash-only book closes" do
    stock.dividends.create!(fiscal_year: "081/082", bonus_percent: 10, book_close_on: Date.new(2026, 9, 1), source: "chukul")
    stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 0, cash_percent: 20, book_close_on: today - 1, source: "chukul")

    expect(described_class.call(on: today)).to include(adjusted: 0)
    expect(item.reload.entry_zone_low.to_f).to eq(500.0)
  end

  it "sends only the adjustment alert on the day of a bonus book close" do
    stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 5, book_close_on: today, source: "chukul")

    expect(described_class.call(on: today)).to include(warned: 0, adjusted: 1)
    expect(item.alerts.pluck(:kind)).to eq([ "levels_adjusted" ])
  end
end
