require "rails_helper"

RSpec.describe WatchlistItem do
  let(:item) { build(:watchlist_item) }

  describe "#price_state_for" do
    it "classifies the price relative to the zone and invalidation level" do
      expect(item.price_state_for(470)).to eq("invalidated")
      expect(item.price_state_for(490)).to eq("below_zone")
      expect(item.price_state_for(500)).to eq("in_zone")
      expect(item.price_state_for(515)).to eq("in_zone")
      expect(item.price_state_for(516)).to eq("extended")
    end
  end

  describe "validations" do
    it "is valid with ordered levels" do
      expect(item).to be_valid
    end

    it "rejects an invalidation level inside the zone" do
      item.invalidation_price = 505
      expect(item).not_to be_valid
      expect(item.errors[:invalidation_price]).to include("must be below the entry zone")
    end

    it "rejects a zone whose high is below its low" do
      item.entry_zone_high = 490
      expect(item).not_to be_valid
    end

    it "rejects a target inside the zone and a stop above the zone low" do
      item.target_price = 510
      item.stop_loss_price = 505
      expect(item).not_to be_valid
      expect(item.errors.attribute_names).to include(:target_price, :stop_loss_price)
    end

    it "allows one item per stock for each user" do
      existing = create(:watchlist_item)
      duplicate = build(:watchlist_item, user: existing.user, stock: existing.stock)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:stock_id]).to include("is already on your watchlist")
    end
  end

  it "computes risk:reward from the zone low, stop and target" do
    expect(item.risk_reward).to eq(2.0) # (560 - 500) / (500 - 470)
  end

  it "measures the distance to the zone low" do
    expect(item.distance_to_zone_pct(480)).to eq(4.17)
    expect(item.distance_to_zone_pct(520)).to eq(-3.85)
  end
end
