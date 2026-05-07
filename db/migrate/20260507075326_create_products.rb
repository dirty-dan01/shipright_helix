class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :sku, null: false
      t.string :name, null: false
      t.text :description
      t.bigint :unit_price_cents, null: false, default: 0
      t.string :currency, null: false, default: "USD"

      t.timestamps
    end
    add_index :products, :sku, unique: true
  end
end
