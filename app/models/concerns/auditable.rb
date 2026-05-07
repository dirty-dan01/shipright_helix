module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_events, as: :auditable, dependent: :destroy
  end

  def record_audit_event!(event:, actor: nil, from_state: nil, to_state: nil, metadata: {}, occurred_at: Time.current)
    audit_events.create!(
      event: event,
      actor: actor,
      from_state: from_state&.to_s,
      to_state: to_state&.to_s,
      metadata: metadata,
      occurred_at: occurred_at
    )
  end
end
