class CreateEquipment < ActiveRecord::Migration[8.1]
  def change
    create_table :equipment do |t|
      t.string :name, null: false
      t.string :asset_identifier, null: false
      t.text :description
      t.string :location, null: false
      t.string :status, null: false
      t.timestamps
    end
    add_index :equipment, :asset_identifier, unique: true
  end
end
