class AllowUsersWithoutCompany < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :company_id, true
  end
end
