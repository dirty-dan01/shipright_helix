class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.bigint :unit_price_cents, null: false
      t.string :currency, null: false, default: "USD"

      t.timestamps
    end
  end
end
