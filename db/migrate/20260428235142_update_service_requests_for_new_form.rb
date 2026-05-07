class UpdateServiceRequestsForNewForm < ActiveRecord::Migration[8.0]
  def change
    change_table :service_requests do |t|
      t.string :customer_phone
      t.string :dropoff_time
      t.string :damage_status # 'NO' | 'YES' | 'DONT_KNOW'
      t.string :replacement_status # 'NO' | 'YES' | 'DONT_KNOW' (or null when N/A for GPS/Chase Drain)
      t.string :rental_status # 'NO' | 'YES' (or null when N/A)
      t.string :rental_during_service_type # equipment type when rental_status == YES
      t.string :replacement_parts, array: true, default: []
    end

    # Existing columns previously required are now optional — see model validations.
    change_column_null :service_requests, :return_date, true
    change_column_null :service_requests, :pickup_date, true
  end
end
