# The paper trading log: every signal, buy, skip, hold and sell, with its reason.
class PaperTradeEvent < ApplicationRecord
  ACTIONS = %w[signal buy skip hold sell].freeze

  belongs_to :user
  belongs_to :paper_trade, optional: true
  belongs_to :stock

  validates :action, inclusion: { in: ACTIONS }
end
