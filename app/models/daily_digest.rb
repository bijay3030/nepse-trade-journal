# One user's end-of-day summary for a session. See Digests::Builder.
class DailyDigest < ApplicationRecord
  SECTIONS = %w[market entry_zone watchlist].freeze

  belongs_to :user

  validates :traded_on, presence: true, uniqueness: { scope: :user_id }

  scope :latest_first, -> { order(traded_on: :desc) }
  scope :unread, -> { where(read_at: nil) }

  # "3 new in the entry zone · 2 watchlist alerts · NEPSE -0.91%"
  def headline
    parts = []
    entry = content["entry_zone"]
    parts << "#{entry['joined'].size} new in the entry zone" if entry && entry["joined"].any?
    watch = content["watchlist"]
    parts << "#{watch['alerts'].size} watchlist #{watch['alerts'].size == 1 ? 'alert' : 'alerts'}" if watch && watch["alerts"].any?
    market = content["market"]
    parts << format("NEPSE %+.2f%%", market["index_change_pct"]) if market && market["index_change_pct"]
    parts.join(" · ").presence || "No changes"
  end
end
