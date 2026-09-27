class Holding < ApplicationRecord
  belongs_to :portfolio
  belongs_to :stock

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :average_buy_price, numericality: { greater_than_or_equal_to: 0 }
end
