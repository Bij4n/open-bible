class AddModerationFieldsToNotes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # No DB-level foreign key on hidden_by / featured_by: if an admin
  # user is ever deleted, we want the moderation action to outlive
  # them (the audit trail is more valuable than referential purity
  # here). disable_ddl_transaction! is required by strong_migrations
  # because we're adding indexes CONCURRENTLY — each index gets its
  # own implicit transaction.
  def change
    add_column :notes, :hidden_at,   :datetime
    add_column :notes, :hidden_by_id, :bigint
    add_column :notes, :featured,    :boolean, null: false, default: false
    add_column :notes, :featured_at, :datetime
    add_column :notes, :featured_by_id, :bigint

    add_index :notes, :hidden_by_id,    algorithm: :concurrently
    add_index :notes, :featured_by_id,  algorithm: :concurrently
    add_index :notes, :hidden_at,       algorithm: :concurrently
    add_index :notes, :featured,
              where: "featured = true",
              name: "index_notes_on_featured_where_true",
              algorithm: :concurrently
  end
end
