class ServiceRequestSerializer
  def initialize(service_request)
    @service_request = service_request
  end

  def as_json
    result = {
      id: @service_request.id,
      user_id: @service_request.user_id,
      customer_name: @service_request.customer_name,
      customer_email: @service_request.user&.email,
      company: @service_request.company,
      service_requested: @service_request.service_requested,
      pickup_date: @service_request.pickup_date,
      return_date: @service_request.return_date,
      dropped_or_impacted: @service_request.dropped_or_impacted,
      needs_replacement_accessories: @service_request.needs_replacement_accessories,
      needs_rush: @service_request.needs_rush,
      needs_rental: @service_request.needs_rental,
      manufacturer: @service_request.manufacturer,
      model: @service_request.model,
      serial_number: @service_request.serial_number,
      created_at: @service_request.created_at,
      updated_at: @service_request.updated_at
    }

    # Add assignment info if present
    if @service_request.assignment
      result[:assigned_user] = {
        id: @service_request.assignment.assigned_to_user.id,
        email: @service_request.assignment.assigned_to_user.email,
        given_name: @service_request.assignment.assigned_to_user.given_name,
        family_name: @service_request.assignment.assigned_to_user.family_name
      }
    else
      result[:assigned_user] = nil
    end

    result
  end
end
