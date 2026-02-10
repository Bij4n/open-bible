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

ActiveRecord::Schema[8.1].define(version: 2026_04_17_093705) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "books", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name_en", null: false
    t.string "name_es", null: false
    t.string "osis_code", null: false
    t.integer "position", null: false
    t.integer "testament", null: false
    t.bigint "translation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["translation_id", "osis_code"], name: "index_books_on_translation_id_and_osis_code", unique: true
    t.index ["translation_id", "position"], name: "index_books_on_translation_id_and_position", unique: true
    t.index ["translation_id"], name: "index_books_on_translation_id"
  end

  create_table "translations", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "language", null: false
    t.text "license_notes", default: "", null: false
    t.string "name", null: false
    t.boolean "public_domain", default: false, null: false
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "index_translations_on_lower_code", unique: true
  end

  add_foreign_key "books", "translations"
end
