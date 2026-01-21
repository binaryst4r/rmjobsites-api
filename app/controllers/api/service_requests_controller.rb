class Api::ServiceRequestsController < ApplicationController
  skip_before_action :authenticate_request, only: [:create]
  before_action :require_admin, only: [:index, :assign]

  def index
    service_requests = ServiceRequest.includes(:user, assignment: :assigned_to_user).order(created_at: :desc)

    render json: {
      service_requests: service_requests.map { |sr| ServiceRequestSerializer.new(sr).as_json }
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
        service_request: ServiceRequestSerializer.new(service_request).as_json,
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
      service_request: ServiceRequestSerializer.new(service_request.reload).as_json,
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
end
