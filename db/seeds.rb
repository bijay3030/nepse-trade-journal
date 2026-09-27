require "httparty"

puts "Seeding NEPSE stocks into database..."
result = Nepse::StockMasterSeeder.seed!
puts "Seeded #{result[:total]} active NEPSE stocks."

puts "Creating default trading strategies..."
default_strategies = [
  {
    name: "Turtle Breakout",
    description: "Buy on 20-day high breakout, sell on 10-day low breakdown"
  },
  {
    name: "Support Bounce",
    description: "Buy at established support with confirmation candle"
  },
  {
    name: "Sector Rotation",
    description: "Enter leading sector, exit lagging sector"
  },
  {
    name: "Dividend Capture",
    description: "Buy before book closure, sell after ex-dividend"
  }
]

default_strategies.each do |strat|
  TradingStrategy.find_or_create_by!(name: strat[:name]) do |s|
    s.description = strat[:description]
    s.is_default = true
  end
end

puts "Database seeding complete."
