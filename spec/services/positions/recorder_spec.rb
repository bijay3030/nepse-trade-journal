require "rails_helper"

RSpec.describe Positions::Recorder do
  let(:user) { create(:user) }
  let(:stock) { create(:stock, last_price: 505) }
  # Zone 500-515, stop 470 (6% below 500), target 560.
  let!(:item) { create(:watchlist_item, user: user, stock: stock, status: "in_zone", price_state: "in_zone") }

  def buy(price: 505, quantity: 100, on: Date.new(2026, 10, 1)) = described_class.buy(user: user, stock: stock, price: price, quantity: quantity, traded_on: on)

  it "opens a position from the watchlist setup and marks the item holding" do
    position = buy

    expect(position).to have_attributes(status: "open", setup_type: "vcp", watchlist_item: item, quantity: 100, average_price: 505.0)
    expect(position.stop_price.to_f).to eq(470.0)
    expect(position.initial_stop_price.to_f).to eq(470.0)
    expect(position.target_price.to_f).to eq(560.0)
    expect(item.reload.status).to eq("holding")
  end

  it "caps a far stop at 8% below the entry" do
    item.update!(stop_loss_price: nil, invalidation_price: 400)

    expect(buy(price: 505).stop_price.to_f).to eq(464.6)
  end

  it "adds later buys to the same open position" do
    first = buy(price: 500, quantity: 100)
    second = buy(price: 520, quantity: 100, on: Date.new(2026, 10, 2))

    expect(second.id).to eq(first.id)
    expect(second).to have_attributes(quantity: 200, average_price: 510.0)
    expect(user.positions.count).to eq(1)
  end

  it "works without a watchlist item, with an 8% stop and no target" do
    other = create(:stock, last_price: 200)
    position = described_class.buy(user: user, stock: other, price: 200, quantity: 10, traded_on: Date.new(2026, 10, 1))

    expect(position).to have_attributes(watchlist_item: nil, target_price: nil)
    expect(position.stop_price.to_f).to eq(184.0)
  end

  it "rejects a bad quantity without leaving a position behind" do
    expect { buy(quantity: 0) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.positions.count).to eq(0)
    expect(item.reload.status).to eq("in_zone")
  end

  it "removes the position with its last fill and puts the item back to tracking" do
    position = buy
    allow(Watchlist::AlertEvaluator).to receive(:initial_state!).and_call_original

    expect(described_class.remove_fill(position.fills.first)).to be_nil
    expect(user.positions.count).to eq(0)
    expect(item.reload.status).to eq("in_zone")
  end

  it "keeps the position when other fills remain" do
    buy(price: 500)
    position = buy(price: 520, on: Date.new(2026, 10, 2))

    expect(described_class.remove_fill(position.fills.last)).to have_attributes(quantity: 100, average_price: 500.0)
    expect(item.reload.status).to eq("holding")
  end
end
