class Api::EquipmentRentalRequestsController < ApplicationController
  skip_before_action :authenticate_request, only: [:create]
  before_action :require_admin, only: [:index]

  def index
    equipment_rental_requests = EquipmentRentalRequest.includes(:user).order(created_at: :desc)

    render json: {
      equipment_rental_requests: equipment_rental_requests.map { |err| EquipmentRentalRequestSerializer.new(err, for: :admin_list).as_json }
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

    equipment_rental_request = EquipmentRentalRequest.new(equipment_rental_request_params)
    equipment_rental_request.user_id = user_id if user_id

    if equipment_rental_request.save
      render json: {
        equipment_rental_request: EquipmentRentalRequestSerializer.new(equipment_rental_request).as_json,
        message: "Equipment rental request submitted successfully"
      }, status: :created
    else
      render json: {
        errors: equipment_rental_request.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: {
      error: "Failed to create equipment rental request: #{e.message}"
    }, status: :internal_server_error
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

  def equipment_rental_request_params
    params.require(:equipment_rental_request).permit(
      :customer_first_name,
      :customer_last_name,
      :customer_email,
      :customer_phone,
      :equipment_type,
      :pickup_date,
      :return_date,
      :rental_agreement_accepted,
      :payment_method
    )
  end
end
