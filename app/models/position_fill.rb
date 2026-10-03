# One buy or sell of a position.
class PositionFill < ApplicationRecord
  SIDES = %w[buy sell].freeze

  belongs_to :position, inverse_of: :fills

  validates :side, inclusion: { in: SIDES }
  validates :price, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :traded_on, presence: true

  def buy? = side == "buy"
end
