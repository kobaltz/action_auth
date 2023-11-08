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

ActiveRecord::Schema[7.1].define(version: 2023_11_07_170349) do
  create_table "action_auth_sessions", force: :cascade do |t|
    t.integer "action_auth_user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_auth_user_id"], name: "index_action_auth_sessions_on_action_auth_user_id"
  end

  create_table "action_auth_users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.boolean "verified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_action_auth_users_on_email", unique: true
  end

  add_foreign_key "action_auth_sessions", "action_auth_users"
end
