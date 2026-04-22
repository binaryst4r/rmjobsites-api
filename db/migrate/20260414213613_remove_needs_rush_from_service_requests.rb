class RemoveNeedsRushFromServiceRequests < ActiveRecord::Migration[8.0]
  def change
    remove_column :service_requests, :needs_rush, :boolean
  end
end
