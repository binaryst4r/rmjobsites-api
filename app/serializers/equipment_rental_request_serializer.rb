class EquipmentRentalRequestSerializer
  def initialize(equipment_rental_request, options = {})
    @equipment_rental_request = equipment_rental_request
    @format = options[:for] || :default
  end

  def as_json
    case @format
    when :admin_list
      admin_list_format
    else
      default_format
    end
  end

  private

  # Default format for create endpoint
  def default_format
    {
      id: @equipment_rental_request.id,
      user_id: @equipment_rental_request.user_id,
      customer_first_name: @equipment_rental_request.customer_first_name,
      customer_last_name: @equipment_rental_request.customer_last_name,
      customer_email: @equipment_rental_request.customer_email,
      customer_phone: @equipment_rental_request.customer_phone,
      equipment_type: @equipment_rental_request.equipment_type,
      pickup_date: @equipment_rental_request.pickup_date,
      return_date: @equipment_rental_request.return_date,
      rental_agreement_accepted: @equipment_rental_request.rental_agreement_accepted,
      payment_method: @equipment_rental_request.payment_method,
      created_at: @equipment_rental_request.created_at,
      updated_at: @equipment_rental_request.updated_at
    }
  end

  # Compact format for admin list view
  def admin_list_format
    {
      id: @equipment_rental_request.id,
      customer_name: "#{@equipment_rental_request.customer_first_name} #{@equipment_rental_request.customer_last_name}",
      customer_email: @equipment_rental_request.customer_email,
      date: "#{@equipment_rental_request.pickup_date} - #{@equipment_rental_request.return_date}",
      equipment: @equipment_rental_request.equipment_type,
      created_at: @equipment_rental_request.created_at
    }
  end
end
