class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.references :translation, null: false, foreign_key: true
      t.string :osis_code, null: false
      t.string :name_en, null: false
      t.string :name_es, null: false
      t.integer :position, null: false
      t.integer :testament, null: false

      t.timestamps
    end

    add_index :books, [ :translation_id, :osis_code ], unique: true
    add_index :books, [ :translation_id, :position ], unique: true
  end
end
