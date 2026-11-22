# A market event already sent to a user on Telegram (Events::Alerts).
class MarketEventDelivery < ApplicationRecord
  belongs_to :user
  belongs_to :market_event
end
