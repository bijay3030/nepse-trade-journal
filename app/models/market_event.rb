# A company announcement or corporate action (Events::Sync), rated for the share price
# by Events::Classifier. stock is nil when no listed company matched.
class MarketEvent < ApplicationRecord
  KINDS = %w[bonus cash_dividend rights book_close results agm merger promoter_sale promoter_lockin issue regulatory credit_rating management other].freeze
  IMPACTS = %w[positive negative mixed neutral].freeze

  belongs_to :stock, optional: true
  has_many :deliveries, class_name: "MarketEventDelivery", dependent: :delete_all

  validates :kind, inclusion: { in: KINDS }
  validates :impact, inclusion: { in: IMPACTS }

  scope :recent, -> { order(published_on: :desc, id: :desc) }
end
