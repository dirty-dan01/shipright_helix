class CreateShipments < ActiveRecord::Migration[8.1]
  def change
    create_table :shipments do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.string :carrier, null: false, default: "fake"
      t.string :tracking_number, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :last_synced_at
      t.string :last_sync_error

      t.timestamps
    end
    add_index :shipments, :tracking_number
  end
end
