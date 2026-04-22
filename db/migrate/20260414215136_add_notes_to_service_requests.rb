class AddNotesToServiceRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :service_requests, :notes, :text
  end
end
