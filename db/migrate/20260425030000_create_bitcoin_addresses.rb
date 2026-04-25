class CreateBitcoinAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :bitcoin_addresses do |t|
      t.string :address, null: false
      t.boolean :active, null: false, default: false
      t.datetime :archived_at
      t.text :notes
      t.timestamps
    end

    # At-most-one-active invariant. Partial unique index is the DB-level
    # backstop; BitcoinAddress.rotate_to! is the application-level path
    # that flips the active row in a transaction. Either path alone would
    # be enough, but together they catch the race condition where two
    # concurrent rotations race past the model-level check.
    add_index :bitcoin_addresses, :active, unique: true, where: "active = true"
  end
end
