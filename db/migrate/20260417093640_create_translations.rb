class CreateTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :translations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :language, null: false
      t.text :license_notes, default: "", null: false
      t.boolean :public_domain, default: false, null: false

      t.timestamps
    end
    add_index :translations, "lower(code)", unique: true, name: "index_translations_on_lower_code"
  end
end
