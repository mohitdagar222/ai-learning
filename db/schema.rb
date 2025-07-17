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

ActiveRecord::Schema[8.0].define(version: 2025_07_16_092712) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "bot_feedbacks", force: :cascade do |t|
    t.text "user_query"
    t.text "bot_response"
    t.boolean "liked"
    t.integer "chunk_ids", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "documents", force: :cascade do |t|
    t.text "content"
    t.vector "embedding", limit: 1536
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prompt_chunks", force: :cascade do |t|
    t.string "link"
    t.text "chunk", null: false
    t.vector "embedding", limit: 1536, null: false
    t.float "quality_score", default: 0.0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
