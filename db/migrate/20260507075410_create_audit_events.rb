class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :auditable, polymorphic: true, null: false, index: true
      t.references :actor, polymorphic: true, null: true, index: true
      t.string :event, null: false
      t.string :from_state
      t.string :to_state
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :audit_events, :event
    add_index :audit_events, :occurred_at
  end
end
