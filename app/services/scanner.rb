module Scanner
  def self.scan(stocks: nil, date: nil, config: Configuration.new)
    Engine.call(stocks: stocks, date: date, config: config)
  end
end
