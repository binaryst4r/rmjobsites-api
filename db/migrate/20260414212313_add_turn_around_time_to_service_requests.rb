class AddTurnAroundTimeToServiceRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :service_requests, :turn_around_time, :string
  end
end
