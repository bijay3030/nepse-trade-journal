class Broker < ApplicationRecord
  validates :broker_no, presence: true, uniqueness: true
  validates :name, presence: true
end
