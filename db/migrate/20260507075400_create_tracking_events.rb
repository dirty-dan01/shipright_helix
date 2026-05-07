class CreateTrackingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :tracking_events do |t|
      t.references :shipment, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :status, null: false
      t.string :location
      t.text :description
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :tracking_events, [ :shipment_id, :external_id ], unique: true
    add_index :tracking_events, :occurred_at
  end
end
