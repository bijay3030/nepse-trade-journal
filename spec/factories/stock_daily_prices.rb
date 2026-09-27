FactoryBot.define do
  factory :stock_daily_price do
    association :stock
    traded_on { Date.current }
    open_price { 500.0 }
    high_price { 510.0 }
    low_price { 495.0 }
    close_price { 505.0 }
    previous_close { 500.0 }
    change_amount { 5.0 }
    change_percent { 1.0 }
    volume { 10_000 }
    turnover { 5_050_000.0 }
    total_trades { 150 }
  end
end
