class AuditEvent < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :actor, polymorphic: true
end
