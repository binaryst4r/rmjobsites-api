class ChangeNeedsReplacementAccessoriesToStringInServiceRequests < ActiveRecord::Migration[8.0]
  def up
    change_column :service_requests, :needs_replacement_accessories, :string
  end

  def down
    change_column :service_requests, :needs_replacement_accessories, :boolean
  end
end
