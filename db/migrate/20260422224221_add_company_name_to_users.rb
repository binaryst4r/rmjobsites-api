class AddCompanyNameToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :company_name, :string
  end
end
