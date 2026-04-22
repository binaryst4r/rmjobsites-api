class AddAfterHoursDropoffToServiceRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :service_requests, :after_hours_dropoff, :boolean
  end
end
