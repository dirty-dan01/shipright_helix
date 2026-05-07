class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :reference, null: false
      t.string :status, null: false, default: "pending"
      t.text :notes

      t.timestamps
    end
    add_index :orders, :reference, unique: true
    add_index :orders, :status
    add_index :orders, :created_at
  end
end
