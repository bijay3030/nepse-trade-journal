class MarketIndex < ApplicationRecord
  has_many :histories, class_name: "MarketIndexHistory", dependent: :destroy

  validates :name, presence: true
  validates :symbol, presence: true, uniqueness: true

  def latest_history
    histories.order(traded_on: :desc).first
  end
end
