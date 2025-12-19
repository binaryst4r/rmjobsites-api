class Api::CustomersController < ApplicationController
  before_action :authenticate_request
  before_action :set_target_user, only: [:show, :update, :orders, :cards, :destroy_card]
  before_action :authorize_customer_access, only: [:show, :update, :orders, :cards, :destroy_card]

  # GET /api/customers/:id
  def show
    # If user has a Square customer ID, fetch from Square and merge with local data
    if @target_user.square_customer_id.present?
      square_service = SquareService.new
      result = square_service.get_customer(@target_user.square_customer_id)

      if result[:customer]
        # Merge Square data with local user data
        customer_data = result[:customer].merge(
          local_user_id: @target_user.id,
          has_square_customer: true
        )
        render json: customer_data, status: :ok
        return
      end
    end

    # If no Square customer, return user data from our database
    render json: user_to_customer_format(@target_user), status: :ok
  rescue StandardError => e
    render json: { error: "Failed to fetch customer: #{e.message}" }, status: :internal_server_error
  end

  # PATCH /api/customers/:id
  def update
    square_service = SquareService.new

    # Update local user data first
    user_attributes = {}
    user_attributes[:given_name] = params[:given_name] if params.key?(:given_name)
    user_attributes[:family_name] = params[:family_name] if params.key?(:family_name)
    user_attributes[:email] = params[:email] if params.key?(:email)
    user_attributes[:phone_number] = params[:phone_number] if params.key?(:phone_number)

    if params[:address].present?
      address_params = params[:address]
      user_attributes[:address_line_1] = address_params[:address_line_1]
      user_attributes[:address_line_2] = address_params[:address_line_2]
      user_attributes[:city] = address_params[:locality]
      user_attributes[:state] = address_params[:administrative_district_level_1]
      user_attributes[:postal_code] = address_params[:postal_code]
      user_attributes[:country] = address_params[:country] || 'US'
    end

    unless @target_user.update(user_attributes.compact)
      render json: { error: "Failed to update user", errors: @target_user.errors.full_messages }, status: :unprocessable_entity
      return
    end

    # If user has a Square customer, update it; otherwise create one
    if @target_user.square_customer_id.present?
      # Update existing Square customer
      square_attributes = build_square_customer_attributes(params)
      result = square_service.update_customer(@target_user.square_customer_id, square_attributes)

      if result[:customer]
        render json: result[:customer], status: :ok
      else
        render json: { error: "Failed to update Square customer", details: result[:errors] }, status: :unprocessable_entity
      end
    else
      # Create new Square customer if we have an email
      if @target_user.email.present?
        customer_result = square_service.find_or_create_customer(
          email: @target_user.email,
          given_name: @target_user.given_name,
          family_name: @target_user.family_name
        )

        if customer_result[:id]
          @target_user.update(square_customer_id: customer_result[:id])
          render json: customer_result, status: :ok
        else
          # Return local user data if Square creation fails
          render json: user_to_customer_format(@target_user), status: :ok
        end
      else
        # No email, just return local user data
        render json: user_to_customer_format(@target_user), status: :ok
      end
    end
  rescue StandardError => e
    render json: { error: "Failed to update customer: #{e.message}" }, status: :internal_server_error
  end

  # GET /api/customers/:id/orders
  def orders
    # Only fetch orders if user has a Square customer ID
    unless @target_user.square_customer_id.present?
      render json: { orders: [] }, status: :ok
      return
    end

    square_service = SquareService.new
    result = square_service.get_customer_orders(@target_user.square_customer_id)

    if result[:orders]
      render json: { orders: result[:orders] }, status: :ok
    else
      render json: { orders: [] }, status: :ok
    end
  rescue StandardError => e
    render json: { error: "Failed to fetch orders: #{e.message}" }, status: :internal_server_error
  end

  # GET /api/customers/:id/cards
  def cards
    # Only fetch cards if user has a Square customer ID
    unless @target_user.square_customer_id.present?
      render json: { cards: [] }, status: :ok
      return
    end

    square_service = SquareService.new
    result = square_service.list_customer_cards(customer_id: @target_user.square_customer_id)

    if result[:cards]
      render json: { cards: result[:cards] }, status: :ok
    else
      render json: { cards: [] }, status: :ok
    end
  rescue StandardError => e
    render json: { error: "Failed to fetch cards: #{e.message}" }, status: :internal_server_error
  end

  # DELETE /api/customers/:id/cards/:card_id
  def destroy_card
    card_id = params[:card_id]

    unless card_id.present?
      render json: { error: "Card ID is required" }, status: :unprocessable_entity
      return
    end

    unless @target_user.square_customer_id.present?
      render json: { error: "No Square customer found" }, status: :not_found
      return
    end

    square_service = SquareService.new
    result = square_service.disable_card(card_id: card_id)

    if result[:card]
      render json: { message: "Card deleted successfully" }, status: :ok
    else
      render json: { error: "Failed to delete card", details: result[:errors] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: "Failed to delete card: #{e.message}" }, status: :internal_server_error
  end

  private

  def set_target_user
    # If :id param is 'me', use current user
    if params[:id] == 'me'
      @target_user = current_user
    else
      # For admin access, find user by their Square customer ID
      @target_user = User.find_by(square_customer_id: params[:id])

      unless @target_user
        render json: { error: "User not found" }, status: :not_found
        return
      end
    end
  end

  def authorize_customer_access
    # Allow if user is admin
    return if current_user.admin?

    # Allow if this is the user's own data
    if current_user.id == @target_user.id
      return
    end

    # Otherwise, deny access
    render json: { error: "Unauthorized" }, status: :forbidden
  end

  # Convert local user model to Square customer format
  def user_to_customer_format(user)
    {
      id: user.square_customer_id || "local_#{user.id}",
      email_address: user.email,
      given_name: user.given_name,
      family_name: user.family_name,
      phone_number: user.phone_number,
      address: {
        address_line_1: user.address_line_1,
        address_line_2: user.address_line_2,
        locality: user.city,
        administrative_district_level_1: user.state,
        postal_code: user.postal_code,
        country: user.country || 'US'
      }.compact,
      local_user_id: user.id,
      has_square_customer: false
    }
  end

  # Build Square customer attributes from params
  def build_square_customer_attributes(params)
    attributes = {}
    attributes[:given_name] = params[:given_name] if params.key?(:given_name)
    attributes[:family_name] = params[:family_name] if params.key?(:family_name)
    attributes[:email_address] = params[:email] if params.key?(:email)
    attributes[:phone_number] = params[:phone_number] if params.key?(:phone_number)

    if params[:address].present?
      address_params = params[:address]
      attributes[:address] = {
        address_line_1: address_params[:address_line_1],
        address_line_2: address_params[:address_line_2],
        locality: address_params[:locality],
        administrative_district_level_1: address_params[:administrative_district_level_1],
        postal_code: address_params[:postal_code],
        country: address_params[:country] || 'US'
      }.compact
    end

    attributes
  end
end
