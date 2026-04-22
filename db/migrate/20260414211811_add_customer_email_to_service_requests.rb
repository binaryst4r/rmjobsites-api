class AddCustomerEmailToServiceRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :service_requests, :customer_email, :string
  end
end
