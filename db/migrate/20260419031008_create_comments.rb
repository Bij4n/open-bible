class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :note, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :comments }
      t.text :body, null: false
      t.integer :depth, null: false, default: 0

      t.timestamps
    end

    # Supports "fetch the thread for this note" ordered by depth/created_at.
    add_index :comments, [ :note_id, :parent_id, :created_at ]
  end
end
