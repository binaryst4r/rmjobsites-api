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

  def default_format
    {
      id: @equipment_rental_request.id,
      user_id: @equipment_rental_request.user_id,
      company_name: @equipment_rental_request.company_name,
      contact_name: @equipment_rental_request.contact_name,
      customer_first_name: @equipment_rental_request.customer_first_name,
      customer_last_name: @equipment_rental_request.customer_last_name,
      customer_email: @equipment_rental_request.customer_email,
      customer_phone: @equipment_rental_request.customer_phone,
      equipment_type: @equipment_rental_request.equipment_type,
      rental_duration_unit: @equipment_rental_request.rental_duration_unit,
      rental_duration_amount: @equipment_rental_request.rental_duration_amount,
      rental_agreement_accepted: @equipment_rental_request.rental_agreement_accepted,
      notes: @equipment_rental_request.notes,
      created_at: @equipment_rental_request.created_at,
      updated_at: @equipment_rental_request.updated_at
    }
  end

  def admin_list_format
    name = display_name
    duration = display_duration
    {
      id: @equipment_rental_request.id,
      customer_name: name,
      company_name: @equipment_rental_request.company_name,
      customer_email: @equipment_rental_request.customer_email,
      duration: duration,
      equipment: @equipment_rental_request.equipment_type,
      created_at: @equipment_rental_request.created_at
    }
  end

  def display_name
    contact = @equipment_rental_request.contact_name
    return contact if contact.present?

    "#{@equipment_rental_request.customer_first_name} #{@equipment_rental_request.customer_last_name}".strip
  end

  def display_duration
    unit = @equipment_rental_request.rental_duration_unit
    amount = @equipment_rental_request.rental_duration_amount
    return nil if unit.blank? || amount.blank?

    "#{amount} #{unit}#{amount.to_i == 1 ? '' : 's'}"
  end
end
