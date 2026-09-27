class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :auditable_type, :auditable_id, :action, presence: true

  def self.track!(record, action:, user: nil, changes_snapshot: {}, metadata: {})
    create!(
      user: user,
      auditable_type: record.class.name,
      auditable_id: record.id,
      action: action,
      changes_snapshot: changes_snapshot || {},
      metadata: metadata || {}
    )
  end
end
