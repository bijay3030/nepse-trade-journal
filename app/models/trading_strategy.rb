class TradingStrategy < ApplicationRecord
  has_many :trade_plans, dependent: :nullify

  validates :name, presence: true, uniqueness: true
end
