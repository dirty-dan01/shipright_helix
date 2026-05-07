class AuditEvent < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :actor, polymorphic: true, optional: true

  validates :event, presence: true
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }

  def status_change?
    from_state.present? || to_state.present?
  end
end
