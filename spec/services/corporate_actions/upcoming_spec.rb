require "rails_helper"

RSpec.describe CorporateActions::Upcoming do
  let(:today) { Date.new(2026, 9, 30) }
  let(:stock) { create(:stock) }

  it "returns the nearest book close within 45 days" do
    stock.dividends.create!(fiscal_year: "081/082", bonus_percent: 5, book_close_on: today - 300, source: "chukul")
    stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, cash_percent: 5, book_close_on: today + 2, agm_on: today + 12, source: "chukul")

    expect(described_class.for_stock(stock, on: today)).to eq(
      fiscal_year: "082/083", book_close_on: today + 2, days_until: 2, cash_percent: 5.0, bonus_percent: 10.0, agm_on: today + 12
    )
  end

  it "ignores past and far-off book closes" do
    stock.dividends.create!(fiscal_year: "082/083", bonus_percent: 10, book_close_on: today + 60, source: "chukul")

    expect(described_class.for_stock(stock, on: today)).to be_nil
  end
end
