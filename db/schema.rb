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

ActiveRecord::Schema[8.1].define(version: 2026_04_25_030001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bitcoin_addresses", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.string "address", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_bitcoin_addresses_on_active", unique: true, where: "(active = true)"
  end

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

  create_table "chapters", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.integer "number", null: false
    t.datetime "updated_at", null: false
    t.integer "verse_count", default: 0, null: false
    t.index ["book_id", "number"], name: "index_chapters_on_book_id_and_number", unique: true
    t.index ["book_id"], name: "index_chapters_on_book_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "depth", default: 0, null: false
    t.bigint "note_id", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["note_id", "parent_id", "created_at"], name: "index_comments_on_note_id_and_parent_id_and_created_at"
    t.index ["note_id"], name: "index_comments_on_note_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "donation_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.text "message"
    t.datetime "updated_at", null: false
  end

  create_table "flags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "details"
    t.bigint "flaggable_id", null: false
    t.string "flaggable_type", null: false
    t.string "reason", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["flaggable_type", "flaggable_id"], name: "index_flags_on_flaggable"
    t.index ["resolved_at"], name: "index_flags_on_resolved_at"
    t.index ["resolved_by_id"], name: "index_flags_on_resolved_by_id"
    t.index ["user_id", "flaggable_type", "flaggable_id"], name: "index_flags_uniqueness", unique: true
    t.index ["user_id"], name: "index_flags_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "invitation_code"
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.integer "privacy", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["invitation_code"], name: "index_groups_on_invitation_code", unique: true, where: "(invitation_code IS NOT NULL)"
    t.index ["owner_id"], name: "index_groups_on_owner_id"
  end

  create_table "highlight_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "highlight_id", null: false
    t.bigint "note_id", null: false
    t.datetime "updated_at", null: false
    t.index ["highlight_id", "note_id"], name: "index_highlight_notes_on_highlight_id_and_note_id", unique: true
    t.index ["highlight_id"], name: "index_highlight_notes_on_highlight_id"
    t.index ["note_id"], name: "index_highlight_notes_on_note_id"
  end

  create_table "highlights", force: :cascade do |t|
    t.integer "color", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "osis_ref", null: false
    t.bigint "translation_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["osis_ref"], name: "index_highlights_on_osis_ref"
    t.index ["translation_id"], name: "index_highlights_on_translation_id"
    t.index ["user_id", "osis_ref", "color"], name: "index_highlights_on_user_osis_ref_color", unique: true
    t.index ["user_id"], name: "index_highlights_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.integer "role", default: 1, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_id", "role"], name: "index_memberships_on_group_id_and_role"
    t.index ["group_id"], name: "index_memberships_on_group_id"
    t.index ["user_id", "group_id"], name: "index_memberships_on_user_id_and_group_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "note_shares", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "note_id", null: false
    t.bigint "shareable_id", null: false
    t.string "shareable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "shareable_type", "shareable_id"], name: "index_note_shares_on_note_and_shareable", unique: true
    t.index ["note_id"], name: "index_note_shares_on_note_id"
    t.index ["shareable_type", "shareable_id"], name: "index_note_shares_on_shareable"
  end

  create_table "notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "featured", default: false, null: false
    t.datetime "featured_at"
    t.bigint "featured_by_id"
    t.datetime "hidden_at"
    t.bigint "hidden_by_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "visibility", default: 0, null: false
    t.index ["featured"], name: "index_notes_on_featured_where_true", where: "(featured = true)"
    t.index ["featured_by_id"], name: "index_notes_on_featured_by_id"
    t.index ["hidden_at"], name: "index_notes_on_hidden_at"
    t.index ["hidden_by_id"], name: "index_notes_on_hidden_by_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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

  create_table "upvotes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "note_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["note_id"], name: "index_upvotes_on_note_id"
    t.index ["user_id", "note_id"], name: "index_upvotes_on_user_id_and_note_id", unique: true
    t.index ["user_id"], name: "index_upvotes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "default_translation_id"
    t.string "display_name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "theme", default: "system", null: false
    t.string "ui_locale", default: "en", null: false
    t.datetime "updated_at", null: false
    t.index "lower((display_name)::text)", name: "index_users_on_lower_display_name", unique: true, where: "(display_name IS NOT NULL)"
    t.index ["default_translation_id"], name: "index_users_on_default_translation_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "char_length(display_name::text) <= 60", name: "users_display_name_length_check"
    t.check_constraint "theme::text = ANY (ARRAY['light'::character varying, 'dark'::character varying, 'system'::character varying]::text[])", name: "users_theme_check"
    t.check_constraint "ui_locale::text = ANY (ARRAY['en'::character varying, 'es'::character varying]::text[])", name: "users_ui_locale_check"
  end

  create_table "verse_embeddings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "embedding_data", null: false
    t.string "model_version", default: "all-MiniLM-L6-v2", null: false
    t.datetime "updated_at", null: false
    t.bigint "verse_id", null: false
    t.index ["verse_id"], name: "index_verse_embeddings_on_verse_id", unique: true
  end

  create_table "verses", force: :cascade do |t|
    t.text "body_html", null: false
    t.text "body_text", null: false
    t.bigint "chapter_id", null: false
    t.datetime "created_at", null: false
    t.integer "number", null: false
    t.string "osis_ref", null: false
    t.jsonb "red_letter_ranges", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["chapter_id", "number"], name: "index_verses_on_chapter_id_and_number", unique: true
    t.index ["chapter_id"], name: "index_verses_on_chapter_id"
    t.index ["osis_ref"], name: "index_verses_on_osis_ref", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "books", "translations"
  add_foreign_key "chapters", "books"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "notes"
  add_foreign_key "comments", "users"
  add_foreign_key "flags", "users"
  add_foreign_key "flags", "users", column: "resolved_by_id"
  add_foreign_key "groups", "users", column: "owner_id"
  add_foreign_key "highlight_notes", "highlights"
  add_foreign_key "highlight_notes", "notes"
  add_foreign_key "highlights", "translations"
  add_foreign_key "highlights", "users"
  add_foreign_key "memberships", "groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "note_shares", "notes"
  add_foreign_key "notes", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "upvotes", "notes"
  add_foreign_key "upvotes", "users"
  add_foreign_key "users", "translations", column: "default_translation_id"
  add_foreign_key "verse_embeddings", "verses"
  add_foreign_key "verses", "chapters"
end
