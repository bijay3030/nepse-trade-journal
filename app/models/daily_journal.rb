class DailyJournal < ApplicationRecord
  include SoftDeletable
  include Auditable

  belongs_to :user
  has_many :versions, class_name: "DailyJournalVersion", dependent: :destroy

  validates :trade_date, presence: true

  before_validation :set_default_trade_date
  after_update_commit :store_version_snapshot, if: :saved_changes?

  private

  def set_default_trade_date
    self.trade_date ||= Date.current
  end

  def store_version_snapshot
    relevant = saved_changes.slice("content", "mood", "discipline_score")
    return if relevant.empty?

    next_version = (versions.maximum(:version_number) || 0) + 1
    versions.create!(
      user: Current.user || user,
      version_number: next_version,
      content: content,
      mood: mood,
      discipline_score: discipline_score
    )
  end
end
