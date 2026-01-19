class CreateServiceRequestAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :service_request_assignments do |t|
      t.references :service_request, null: false, foreign_key: true
      t.references :assigned_to_user, null: false, foreign_key: { to_table: :users }
      t.references :assigned_by_user, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
