class Api::OrdersController < ApplicationController
  skip_before_action :authenticate_request, only: [:calculate]
  before_action :authenticate_request, only: [:create]

  # POST /api/orders/calculate
  # Calculate order totals without creating the order
  def calculate
    line_items = params[:line_items]
    fulfillment_type = params[:fulfillment_type] || 'PICKUP'

    unless line_items.present?
      render json: { error: "Line items are required" }, status: :unprocessable_entity
      return
    end

    # Build order object for Square
    order = {
      location_id: Rails.application.config.square[:location_id],
      line_items: format_line_items(line_items)
    }

    # Add service charge for shipping (pickup is free)
    if fulfillment_type == 'SHIPMENT'
      # You can adjust shipping cost calculation here
      # For now, keeping existing service charge behavior
    end

    square_service = SquareService.new
    result = square_service.calculate_order(order)

    if result[:order]
      calculated = format_calculated_order(result[:order])
      # Override shipping to $0 for pickup orders
      calculated[:shipping] = 0 if fulfillment_type == 'PICKUP'
      calculated[:total] = calculated[:subtotal] + calculated[:taxes] + calculated[:shipping]
      render json: calculated, status: :ok
    else
      render json: { error: "Failed to calculate order", details: result[:errors] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: "Failed to calculate order: #{e.message}" }, status: :internal_server_error
  end

  # POST /api/orders
  # Create an order with payment
  def create
    line_items = params[:line_items]
    payment_token = params[:payment_token]
    customer_info = params[:customer_info]
    shipping_address = params[:shipping_address]
    fulfillment_type = params[:fulfillment_type] || 'PICKUP'
    pickup_details = params[:pickup_details]

    # Validate required params
    unless line_items.present? && payment_token.present? && customer_info.present?
      render json: { error: "Line items, payment token, and customer info are required" }, status: :unprocessable_entity
      return
    end

    # Validate fulfillment type
    unless ['PICKUP', 'SHIPMENT'].include?(fulfillment_type)
      render json: { error: "Invalid fulfillment type. Must be PICKUP or SHIPMENT" }, status: :unprocessable_entity
      return
    end

    # Validate fulfillment-specific requirements
    if fulfillment_type == 'SHIPMENT'
      # Validate shipping address fields
      if shipping_address.blank? ||
         shipping_address[:address_line_1].blank? ||
         shipping_address[:locality].blank? ||
         shipping_address[:administrative_district_level_1].blank? ||
         shipping_address[:postal_code].blank?
        render json: { error: "Shipping address (address line 1, city, state, and postal code) is required for shipment orders" }, status: :unprocessable_entity
        return
      end
    elsif fulfillment_type == 'PICKUP'
      # Validate pickup details
      if pickup_details.blank? || pickup_details[:date].blank? || pickup_details[:time].blank?
        render json: { error: "Pickup date and time are required for pickup orders" }, status: :unprocessable_entity
        return
      end

      # Validate pickup date is not in the past
      begin
        pickup_date = Date.parse(pickup_details[:date])
        if pickup_date < Date.today
          render json: { error: "Pickup date cannot be in the past" }, status: :unprocessable_entity
          return
        end

        # Validate not a weekend
        if pickup_date.saturday? || pickup_date.sunday?
          render json: { error: "Pickup is not available on weekends. Please contact us for weekend arrangements." }, status: :unprocessable_entity
          return
        end
      rescue ArgumentError
        render json: { error: "Invalid pickup date format" }, status: :unprocessable_entity
        return
      end

      # Validate pickup time is within business hours (8 AM - 5 PM)
      begin
        time_parts = pickup_details[:time].split(':')
        hour = time_parts[0].to_i
        if hour < 8 || hour >= 17
          render json: { error: "Pickup time must be between 8:00 AM and 5:00 PM" }, status: :unprocessable_entity
          return
        end
      rescue
        render json: { error: "Invalid pickup time format" }, status: :unprocessable_entity
        return
      end
    end

    square_service = SquareService.new

    # Find or create Square customer
    customer = square_service.find_or_create_customer(
      email: customer_info[:email],
      given_name: customer_info[:given_name],
      family_name: customer_info[:family_name]
    )

    square_customer_id = customer[:id]

    # Update current user with Square customer ID and profile info
    if current_user
      user_updates = {}

      # Save Square customer ID if not already set
      user_updates[:square_customer_id] = square_customer_id if current_user.square_customer_id.blank?

      # Save customer name if provided
      user_updates[:given_name] = customer_info[:given_name] if customer_info[:given_name].present?
      user_updates[:family_name] = customer_info[:family_name] if customer_info[:family_name].present?

      # Save shipping address if provided (only for shipment orders)
      if fulfillment_type == 'SHIPMENT' && shipping_address.present?
        user_updates[:address_line_1] = shipping_address[:address_line_1] if shipping_address[:address_line_1].present?
        user_updates[:address_line_2] = shipping_address[:address_line_2] if shipping_address[:address_line_2].present?
        user_updates[:city] = shipping_address[:locality] if shipping_address[:locality].present?
        user_updates[:state] = shipping_address[:administrative_district_level_1] if shipping_address[:administrative_district_level_1].present?
        user_updates[:postal_code] = shipping_address[:postal_code] if shipping_address[:postal_code].present?
        user_updates[:country] = shipping_address[:country] || 'US'
      end

      current_user.update(user_updates) if user_updates.any?

      # Update Square customer with address if provided (only for shipment)
      if fulfillment_type == 'SHIPMENT' && shipping_address.present?
        square_service.update_customer(square_customer_id, {
          address: {
            address_line_1: shipping_address[:address_line_1],
            address_line_2: shipping_address[:address_line_2],
            locality: shipping_address[:locality],
            administrative_district_level_1: shipping_address[:administrative_district_level_1],
            postal_code: shipping_address[:postal_code],
            country: shipping_address[:country] || 'US'
          }.compact
        })
      end
    end

    # Build fulfillment array for Square
    fulfillments = []
    recipient_name = "#{customer_info[:given_name]} #{customer_info[:family_name]}".strip
    recipient_name = customer_info[:email] if recipient_name.blank?

    if fulfillment_type == 'PICKUP'
      # Combine date and time into ISO8601 timestamp
      pickup_datetime = DateTime.parse("#{pickup_details[:date]} #{pickup_details[:time]}")
      fulfillments << square_service.build_pickup_fulfillment(
        recipient_name: recipient_name,
        recipient_email: customer_info[:email],
        recipient_phone: current_user&.phone_number,
        pickup_at: pickup_datetime.iso8601
      )
    elsif fulfillment_type == 'SHIPMENT'
      fulfillments << square_service.build_shipment_fulfillment(
        recipient_name: recipient_name,
        recipient_email: customer_info[:email],
        recipient_phone: current_user&.phone_number,
        address: shipping_address
      )
    end

    # Create the order with fulfillments
    order_result = square_service.create_order(
      line_items: format_line_items(line_items),
      customer_id: square_customer_id,
      fulfillments: fulfillments
    )

    unless order_result[:order]
      render json: { error: "Failed to create order", details: order_result[:errors] }, status: :unprocessable_entity
      return
    end

    order = order_result[:order]
    order_id = order[:id]
    total_amount = order.dig(:total_money, :amount)
    currency = order.dig(:total_money, :currency) || 'USD'

    # Create payment
    payment_result = square_service.create_payment(
      source_id: payment_token,
      amount_money: {
        amount: total_amount,
        currency: currency
      },
      order_id: order_id,
      customer_id: square_customer_id
    )

    if payment_result[:payment]
      # Send order confirmation email
      begin
        sendgrid_service = SendgridService.new
        sendgrid_service.send_order_confirmation(
          order: order,
          payment: payment_result[:payment],
          customer: customer,
          fulfillment_type: fulfillment_type
        )
      rescue StandardError => e
        # Log error but don't fail the order
        Rails.logger.error "Failed to send order confirmation email: #{e.message}"
      end

      render json: {
        order: order,
        payment: payment_result[:payment],
        customer: customer
      }, status: :created
    else
      render json: { error: "Payment failed", details: payment_result[:errors] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: "Failed to create order: #{e.message}" }, status: :internal_server_error
  end

  private

  def format_line_items(line_items_params)
    line_items_params.map do |item|
      {
        catalog_object_id: item[:catalog_object_id] || item[:variation_id],
        quantity: item[:quantity].to_s
      }
    end
  end

  def format_calculated_order(order)
    line_items = order[:line_items] || []

    subtotal = line_items.sum do |item|
      item.dig(:total_money, :amount) || 0
    end

    taxes = (order[:total_tax_money] && order[:total_tax_money][:amount]) || 0
    shipping = (order[:total_service_charge_money] && order[:total_service_charge_money][:amount]) || 0
    total = (order[:total_money] && order[:total_money][:amount]) || 0

    {
      subtotal: subtotal,
      taxes: taxes,
      shipping: shipping,
      total: total,
      line_items: line_items.map do |item|
        {
          catalog_object_id: item[:catalog_object_id],
          quantity: item[:quantity],
          name: item[:name],
          total_money: item[:total_money]
        }
      end
    }
  end
end
