# A stock's running volume at one moment of a session. See Nepse::VolumeProfile.
class StockIntradayVolume < ApplicationRecord
  belongs_to :stock
end
