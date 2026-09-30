# One broker's buying and selling in one stock on one day, rolled up from the floorsheet.
class StockBrokerFlow < ApplicationRecord
  belongs_to :stock

  def net_quantity = buy_quantity - sell_quantity
end
