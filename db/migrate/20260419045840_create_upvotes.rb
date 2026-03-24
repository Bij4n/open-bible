class CreateUpvotes < ActiveRecord::Migration[8.1]
  def change
    create_table :upvotes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :note, null: false, foreign_key: true

      t.timestamps
    end

    add_index :upvotes, [ :user_id, :note_id ], unique: true
  end
end
