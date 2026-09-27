class DailyJournalVersion < ApplicationRecord
  belongs_to :daily_journal
  belongs_to :user, optional: true

  validates :version_number, presence: true
end
