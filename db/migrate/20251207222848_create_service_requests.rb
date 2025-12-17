class CreateServiceRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :service_requests do |t|
      t.references :user, null: true, foreign_key: true
      t.string :customer_name
      t.string :company
      t.string :service_requested
      t.date :pickup_date
      t.date :return_date
      t.boolean :dropped_or_impacted
      t.boolean :needs_replacement_accessories
      t.boolean :needs_rush
      t.boolean :needs_rental
      t.string :manufacturer
      t.string :model
      t.string :serial_number

      t.timestamps
    end
  end
end
