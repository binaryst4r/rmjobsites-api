class UpdateEquipmentRentalRequestsForNewForm < ActiveRecord::Migration[8.0]
  def change
    change_table :equipment_rental_requests do |t|
      t.string :company_name
      t.string :contact_name
      t.string :rental_duration_unit
      t.integer :rental_duration_amount
      t.text :notes
    end

    change_column_null :equipment_rental_requests, :pickup_date, true
    change_column_null :equipment_rental_requests, :return_date, true
  end
end
