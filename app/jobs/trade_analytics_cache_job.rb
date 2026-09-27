class TradeAnalyticsCacheJob < ApplicationJob
  queue_as :default

  def perform(_user)
    prices = refresh_prices
    ActionCable.server.broadcast("stock_prices", { prices: prices, broadcasted_at: Time.current })
  end

  private

  def refresh_prices
    Stock.limit(200).map do |stock|
      price_data = NepsePriceService.new(stock.symbol).fetch_current
      stock.apply_live_quote!(price_data) if price_data
      stock.price_payload
    end.compact
  end
end
