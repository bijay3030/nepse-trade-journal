FactoryBot.define do
  factory :stock do
    sequence(:symbol) { |n| "NABIL#{n}" }
    name { "Nabil Bank Limited" }
    sector { "Commercial Banks" }
    security_type { "Equity" }
    last_price { 500.0 }
    listed_shares { 100_000_000 }
    market_cap { 50_000_000_000.0 }
    high_52w { 600.0 }
    low_52w { 400.0 }
    last_updated { Time.current }
  end
end
