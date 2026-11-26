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

ActiveRecord::Schema[8.1].define(version: 2026_11_26_075242) do
  create_table "games", force: :cascade do |t|
    t.string "public_id", null: false
    t.string "host_token_digest", null: false
    t.string "join_code", limit: 6, null: false
    t.datetime "joining_closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["host_token_digest"], name: "index_games_on_host_token_digest", unique: true
    t.index ["join_code"], name: "index_games_on_join_code_while_open", unique: true, where: "joining_closed_at IS NULL"
    t.index ["public_id"], name: "index_games_on_public_id", unique: true
  end

  create_table "seats", force: :cascade do |t|
    t.integer "game_id", null: false
    t.string "power", null: false
    t.string "token_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "power"], name: "index_seats_on_game_id_and_power", unique: true
    t.index ["token_digest"], name: "index_seats_on_token_digest", unique: true
  end

  add_foreign_key "seats", "games"
end
