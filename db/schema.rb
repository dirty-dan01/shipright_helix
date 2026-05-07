# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_07_075410) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "actor_type"
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.string "from_state"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.string "to_state"
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_audit_events_on_actor"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["event"], name: "index_audit_events_on_event"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_customers_on_email", unique: true
  end

  create_table "line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.bigint "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["product_id"], name: "index_line_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "notes"
    t.string "reference", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["reference"], name: "index_orders_on_reference", unique: true
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "description"
    t.string "name", null: false
    t.string "sku", null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shipments", force: :cascade do |t|
    t.string "carrier", default: "fake", null: false
    t.datetime "created_at", null: false
    t.string "last_sync_error"
    t.datetime "last_synced_at"
    t.bigint "order_id", null: false
    t.string "status", default: "pending", null: false
    t.string "tracking_number", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_shipments_on_order_id", unique: true
    t.index ["tracking_number"], name: "index_shipments_on_tracking_number"
  end

  create_table "tracking_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "external_id", null: false
    t.string "location"
    t.datetime "occurred_at", null: false
    t.bigint "shipment_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["occurred_at"], name: "index_tracking_events_on_occurred_at"
    t.index ["shipment_id", "external_id"], name: "index_tracking_events_on_shipment_id_and_external_id", unique: true
    t.index ["shipment_id"], name: "index_tracking_events_on_shipment_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "line_items", "orders"
  add_foreign_key "line_items", "products"
  add_foreign_key "orders", "customers"
  add_foreign_key "sessions", "users"
  add_foreign_key "shipments", "orders"
  add_foreign_key "tracking_events", "shipments"
end
