FactoryBot.define do
  factory :market_index do
    name { "NEPSE Index" }
    sequence(:symbol) { |n| "NEPSE#{n}" }
    current_value { 2000.0 }
    change_point { 10.0 }
    change_percent { 0.5 }
  end

  factory :market_index_history do
    association :market_index
    traded_on { Date.current }
    index_value { 2000.0 }
    change_point { 10.0 }
    change_percent { 0.5 }
    turnover { 1_000_000_000.0 }
  end
end
