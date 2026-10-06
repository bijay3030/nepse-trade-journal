require "rails_helper"

RSpec.describe Positions::Recorder, ".sell" do
  let(:user) { create(:user) }
  let(:stock) { create(:stock, last_price: 120) }
  let(:item) { create(:watchlist_item, user: user, stock: stock, status: "holding") }
  # 100 bought on Thursday 2026-09-24: settles Monday 2026-09-28 (Fri/Sat closed).
  let(:position) { described_class.buy(user: user, stock: stock, watchlist_item: item, price: 100, quantity: 100, traded_on: Date.new(2026, 9, 24)) }

  it "records a partial sell, then closes the position and archives its watchlist item" do
    partial, warning = described_class.sell(position: position, price: 115, quantity: 40, traded_on: "2026-09-29")
    expect(partial).to have_attributes(status: "open", quantity: 60)
    expect(warning).to be_nil
    expect(partial.realized[:gain]).to be_positive

    closed, = described_class.sell(position: partial, price: 120, quantity: 60, traded_on: "2026-09-30")
    expect(closed).to have_attributes(status: "closed", closed_on: Date.new(2026, 9, 30), quantity: 0)
    expect(item.reload.status).to eq("archived")
    expect(closed.average_sell_price).to eq(118.0)
  end

  it "warns about unsettled shares but records the sell" do
    _, warning = described_class.sell(position: position, price: 105, quantity: 50, traded_on: "2026-09-25")

    expect(warning).to eq("50 of these shares hadn't settled (T+2) on 25 Sep")
    expect(position.reload.quantity).to eq(50)
  end

  it "refuses to sell more than is held" do
    expect { described_class.sell(position: position, price: 105, quantity: 150, traded_on: "2026-09-29") }.to raise_error(ArgumentError, /hold 100 shares/)
  end

  it "reopens the position when its closing sell is removed" do
    closed, = described_class.sell(position: position, price: 120, quantity: 100, traded_on: "2026-09-30")

    reopened = described_class.remove_fill(closed.fills.find { !_1.buy? })
    expect(reopened).to have_attributes(status: "open", closed_on: nil, quantity: 100)
  end
end
