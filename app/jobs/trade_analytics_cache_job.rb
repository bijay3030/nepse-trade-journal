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
      next stock.price_payload unless price_data

      stock.update(
        last_price: price_data[:last_price],
        change_percent: price_data[:change_percent],
        volume: price_data[:volume],
        last_updated: Time.current
      )
      stock.price_payload
    end.compact
  end
end
