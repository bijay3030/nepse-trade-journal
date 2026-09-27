class StockPricesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stock_prices"
  end

  def unsubscribed
    stop_all_streams
  end
end
