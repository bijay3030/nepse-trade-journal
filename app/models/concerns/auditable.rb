module Auditable
  extend ActiveSupport::Concern

  included do
    after_create_commit :audit_create
    after_update_commit :audit_update
  end

  private

  def audit_create
    AuditLog.track!(self, action: "create", user: Current.user, changes_snapshot: previous_changes.except(:updated_at))
  end

  def audit_update
    meaningful_changes = previous_changes.except(:updated_at)
    return if meaningful_changes.empty?

    AuditLog.track!(self, action: "update", user: Current.user, changes_snapshot: meaningful_changes)
  end
end
