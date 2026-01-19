class Api::ServiceRequestsController < ApplicationController
  skip_before_action :authenticate_request, only: [:create]
  before_action :require_admin, only: [:index, :assign]

  def index
    service_requests = ServiceRequest.includes(:user, assignment: :assigned_to_user).order(created_at: :desc)

    render json: {
      service_requests: service_requests.map { |sr| format_service_request(sr) }
    }, status: :ok
  end

  def create
    # Extract user_id from token if present
    user_id = nil
    begin
      header = request.headers["Authorization"]
      if header
        token = header.split(" ").last
        decoded = JsonWebToken.decode(token)
        user_id = decoded[:user_id] if decoded
      end
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      # Continue without user_id if token is invalid or user not found
    end

    service_request = ServiceRequest.new(service_request_params)
    service_request.user_id = user_id if user_id

    if service_request.save
      render json: {
        service_request: format_service_request(service_request),
        message: "Service request submitted successfully"
      }, status: :created
    else
      render json: {
        errors: service_request.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: {
      error: "Failed to create service request: #{e.message}"
    }, status: :internal_server_error
  end

  def assign
    service_request = ServiceRequest.find(params[:id])
    assigned_to_user = User.find(params[:assigned_to_user_id])

    unless assigned_to_user.admin?
      render json: { error: "User must be an admin" }, status: :unprocessable_entity
      return
    end

    # Check if assignment already exists
    if service_request.assignment
      # Update existing assignment
      service_request.assignment.update!(
        assigned_to_user: assigned_to_user,
        assigned_by_user: current_user
      )
    else
      # Create new assignment
      service_request.create_assignment!(
        assigned_to_user: assigned_to_user,
        assigned_by_user: current_user
      )
    end

    render json: {
      service_request: format_service_request(service_request.reload),
      message: "Service request assigned successfully"
    }, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: "Record not found: #{e.message}" }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: "Failed to assign service request: #{e.message}" }, status: :internal_server_error
  end

  private

  def require_admin
    unless current_user
      render json: { error: "Unauthorized. Please log in." }, status: :unauthorized
      return
    end

    unless current_user.admin?
      render json: { error: "Unauthorized. Admin access required." }, status: :forbidden
    end
  end

  def service_request_params
    params.require(:service_request).permit(
      :customer_name,
      :company,
      :service_requested,
      :pickup_date,
      :return_date,
      :dropped_or_impacted,
      :needs_replacement_accessories,
      :needs_rush,
      :needs_rental,
      :manufacturer,
      :model,
      :serial_number
    )
  end

  def format_service_request(service_request)
    result = {
      id: service_request.id,
      user_id: service_request.user_id,
      customer_name: service_request.customer_name,
      customer_email: service_request.user&.email,
      company: service_request.company,
      service_requested: service_request.service_requested,
      pickup_date: service_request.pickup_date,
      return_date: service_request.return_date,
      dropped_or_impacted: service_request.dropped_or_impacted,
      needs_replacement_accessories: service_request.needs_replacement_accessories,
      needs_rush: service_request.needs_rush,
      needs_rental: service_request.needs_rental,
      manufacturer: service_request.manufacturer,
      model: service_request.model,
      serial_number: service_request.serial_number,
      created_at: service_request.created_at,
      updated_at: service_request.updated_at
    }

    # Add assignment info if present
    if service_request.assignment
      result[:assigned_user] = {
        id: service_request.assignment.assigned_to_user.id,
        email: service_request.assignment.assigned_to_user.email,
        given_name: service_request.assignment.assigned_to_user.given_name,
        family_name: service_request.assignment.assigned_to_user.family_name
      }
    else
      result[:assigned_user] = nil
    end

    result
  end
end
