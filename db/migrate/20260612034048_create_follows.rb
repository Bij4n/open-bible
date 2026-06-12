class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followed, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    # One row per (follower, followed) pair; the reverse direction is a
    # separate row. Mutual pairs are "friends" (User#friends).
    add_index :follows, [ :follower_id, :followed_id ], unique: true

    # Belt-and-suspenders under the model validation: no self-follows
    # through any code path (console, seeds, future bulk imports).
    add_check_constraint :follows, "follower_id <> followed_id", name: "no_self_follows"
  end
end
