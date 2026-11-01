class AddStatusIndexToMaintenanceTickets < ActiveRecord::Migration[8.1]
  def change
    add_index :maintenance_tickets, :status
  end
end
