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

ActiveRecord::Schema[8.0].define(version: 2026_01_06_025654) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "equipment_rental_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.string "customer_first_name"
    t.string "customer_last_name"
    t.string "customer_email"
    t.string "customer_phone"
    t.string "equipment_type"
    t.date "pickup_date"
    t.date "return_date"
    t.boolean "rental_agreement_accepted"
    t.string "payment_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_equipment_rental_requests_on_user_id"
  end

  create_table "service_request_assignments", force: :cascade do |t|
    t.bigint "service_request_id", null: false
    t.bigint "assigned_to_user_id", null: false
    t.bigint "assigned_by_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_user_id"], name: "index_service_request_assignments_on_assigned_by_user_id"
    t.index ["assigned_to_user_id"], name: "index_service_request_assignments_on_assigned_to_user_id"
    t.index ["service_request_id"], name: "index_service_request_assignments_on_service_request_id"
  end

  create_table "service_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.string "customer_name"
    t.string "company"
    t.string "service_requested"
    t.date "pickup_date"
    t.date "return_date"
    t.boolean "dropped_or_impacted"
    t.boolean "needs_replacement_accessories"
    t.boolean "needs_rush"
    t.boolean "needs_rental"
    t.string "manufacturer"
    t.string "model"
    t.string "serial_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_service_requests_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.string "square_customer_id"
    t.string "given_name"
    t.string "family_name"
    t.string "phone_number"
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "equipment_rental_requests", "users"
  add_foreign_key "service_request_assignments", "service_requests"
  add_foreign_key "service_request_assignments", "users", column: "assigned_by_user_id"
  add_foreign_key "service_request_assignments", "users", column: "assigned_to_user_id"
  add_foreign_key "service_requests", "users"
end
