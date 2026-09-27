FactoryBot.define do
  factory :stock_daily_indicator do
    association :stock
    association :stock_daily_price
    traded_on { Date.current }
    sma_20 { 500.0 }
    sma_50 { 495.0 }
    sma_200 { 480.0 }
    avg_volume_20 { 10_000 }
  end
end
