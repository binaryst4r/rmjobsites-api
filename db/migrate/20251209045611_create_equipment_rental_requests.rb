class CreateEquipmentRentalRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :equipment_rental_requests do |t|
      t.references :user, null: true, foreign_key: true
      t.string :customer_first_name
      t.string :customer_last_name
      t.string :customer_email
      t.string :customer_phone
      t.string :equipment_type
      t.date :pickup_date
      t.date :return_date
      t.boolean :rental_agreement_accepted
      t.string :payment_method

      t.timestamps
    end
  end
end
