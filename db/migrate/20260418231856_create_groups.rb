class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.text :description
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.integer :privacy, null: false, default: 0
      t.string :invitation_code

      t.timestamps
    end

    add_index :groups, :invitation_code, unique: true, where: "invitation_code IS NOT NULL"
  end
end
