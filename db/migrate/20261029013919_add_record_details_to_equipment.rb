class AddRecordDetailsToEquipment < ActiveRecord::Migration[8.1]
  def change
    add_column :equipment, :manufacture_date, :date
    add_column :equipment, :specifications, :text
  end
end
