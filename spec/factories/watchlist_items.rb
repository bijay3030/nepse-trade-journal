FactoryBot.define do
  factory :watchlist_item do
    user
    stock
    setup_type { "vcp" }
    status { "watching" }
    entry_zone_low { 500.0 }
    entry_zone_high { 515.0 }
    invalidation_price { 470.0 }
    stop_loss_price { 470.0 }
    target_price { 560.0 }
    pivot_price { 500.0 }
  end
end
