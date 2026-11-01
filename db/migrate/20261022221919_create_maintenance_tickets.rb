class CreateMaintenanceTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_tickets do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :priority, null: false
      t.string :status, null: false, default: "open"

      t.references :equipment, null: false, foreign_key: true
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :assigned_technician, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
