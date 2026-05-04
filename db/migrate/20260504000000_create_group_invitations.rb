class CreateGroupInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :group_invitations do |t|
      t.references :group, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    # Token lookup is the primary read path (when a recipient clicks the
    # email link, we look up by token). Always-unique across rows.
    add_index :group_invitations, :token, unique: true

    # Unique pending invite per (group, email) — prevents the owner from
    # spamming the same address with duplicate invites. accepted_at IS
    # NULL identifies pending; once accepted we no longer enforce uniqueness
    # so a future kicked-and-re-invited cycle works.
    add_index :group_invitations,
              [ :group_id, :email ],
              unique: true,
              where: "accepted_at IS NULL",
              name: "index_group_invitations_pending_uniq"
  end
end
