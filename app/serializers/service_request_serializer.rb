class ServiceRequestSerializer
  def initialize(service_request)
    @service_request = service_request
  end

  def as_json
    result = {
      id: @service_request.id,
      user_id: @service_request.user_id,
      customer_name: @service_request.customer_name,
      customer_email: @service_request.customer_email,
      customer_phone: @service_request.customer_phone,
      company: @service_request.company,
      service_requested: @service_request.service_requested,
      pickup_date: @service_request.pickup_date,
      dropoff_time: @service_request.dropoff_time,
      damage_status: @service_request.damage_status,
      replacement_status: @service_request.replacement_status,
      replacement_parts: @service_request.replacement_parts || [],
      rental_status: @service_request.rental_status,
      rental_during_service_type: @service_request.rental_during_service_type,
      dropped_or_impacted: @service_request.dropped_or_impacted,
      needs_replacement_accessories: @service_request.needs_replacement_accessories,
      needs_rental: @service_request.needs_rental,
      manufacturer: @service_request.manufacturer,
      model: @service_request.model,
      serial_number: @service_request.serial_number,
      turn_around_time: @service_request.turn_around_time,
      after_hours_dropoff: @service_request.after_hours_dropoff,
      notes: @service_request.notes,
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
