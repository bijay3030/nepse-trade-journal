# A daily price older than the stock's stock_daily_prices. See Scans::History.
class StockPriceArchive < ApplicationRecord
  belongs_to :stock
end
