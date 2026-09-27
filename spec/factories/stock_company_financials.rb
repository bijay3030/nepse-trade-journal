FactoryBot.define do
  factory :stock_company_financial do
    association :stock
    fiscal_year { "2080/81" }
    quarter { "Q4" }
    reported_on { Date.current }
    eps { 25.5 }
    pe_ratio { 19.6 }
    book_value { 210.0 }
    pb_ratio { 2.38 }
    roe { 12.5 }
    net_profit { 3_500_000_000.0 }
  end
end
