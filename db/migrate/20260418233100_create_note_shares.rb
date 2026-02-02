class CreateNoteShares < ActiveRecord::Migration[8.1]
  def change
    create_table :note_shares do |t|
      t.references :note, null: false, foreign_key: true
      t.references :shareable, polymorphic: true, null: false

      t.timestamps
    end

    # Strong_migrations flags changing an existing index to unique, but we
    # just generated the default shareable index above; replace it with
    # the uniqueness-aware composite before any data exists.
    remove_index :note_shares, [ :shareable_type, :shareable_id ]
    add_index :note_shares, [ :note_id, :shareable_type, :shareable_id ],
              unique: true,
              name: "index_note_shares_on_note_and_shareable"
    add_index :note_shares, [ :shareable_type, :shareable_id ],
              name: "index_note_shares_on_shareable"
  end
end
