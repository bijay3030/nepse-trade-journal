module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    default_scope { kept }
  end

  def soft_delete!(metadata = {})
    return if deleted_at?

    update!(deleted_at: Time.current)
    AuditLog.track!(self, action: "soft_delete", user: Current.user, metadata: metadata)
  end

  def restore!(metadata = {})
    return unless deleted_at?

    update!(deleted_at: nil)
    AuditLog.track!(self, action: "restore", user: Current.user, metadata: metadata)
  end
end
