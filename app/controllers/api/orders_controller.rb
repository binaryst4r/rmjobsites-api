class Api::OrdersController < ApplicationController
  skip_before_action :authenticate_request, only: [:calculate, :phone_call_request]
  before_action :authenticate_request, only: [:create]

  DELIVERY_TIER_LABELS = {
    'next_day' => 'Next Day',
    'two_day' => '2-Day',
    'three_day' => '3-Day'
  }.freeze

  # POST /api/orders/calculate
  # Calculate order totals without creating the order
  def calculate
    line_items = params[:line_items]
    fulfillment_type = params[:fulfillment_type] || 'PICKUP'

    unless line_items.present?
      render json: { error: "Line items are required" }, status: :unprocessable_entity
      return
    end

    # Build order object for Square. Auto-apply the location's configured taxes
    # to every order — origin-sourced for shipments (single CO location).
    order = {
      location_id: Rails.application.config.square[:location_id],
      line_items: format_line_items(line_items),
      pricing_options: { auto_apply_taxes: true }
    }

    square_service = SquareService.new
    result = square_service.calculate_order(order)

    if result[:order]
      calculated = format_calculated_order(result[:order])
      # Override shipping to $0 for pickup and delivery (delivery is selection-only,
      # priced/coordinated by staff after order placement).
      calculated[:shipping] = 0 if %w[PICKUP DELIVERY].include?(fulfillment_type)
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
    pickup_variant = params[:pickup_variant] || 'normal'
    delivery_tier = params[:delivery_tier]

    # Validate required params
    unless line_items.present? && payment_token.present? && customer_info.present?
      render json: { error: "Line items, payment token, and customer info are required" }, status: :unprocessable_entity
      return
    end

    # Validate fulfillment type
    unless %w[PICKUP DELIVERY SHIPMENT].include?(fulfillment_type)
      render json: { error: "Invalid fulfillment type. Must be PICKUP, DELIVERY, or SHIPMENT" }, status: :unprocessable_entity
      return
    end

    # Validate fulfillment-specific requirements
    if fulfillment_type == 'SHIPMENT' || fulfillment_type == 'DELIVERY'
      # Both shipping and delivery require an address (delivery within 50-mile radius)
      if shipping_address.blank? ||
         shipping_address[:address_line_1].blank? ||
         shipping_address[:locality].blank? ||
         shipping_address[:administrative_district_level_1].blank? ||
         shipping_address[:postal_code].blank?
        render json: { error: "Address (line 1, city, state, and postal code) is required for #{fulfillment_type.downcase} orders" }, status: :unprocessable_entity
        return
      end

      if fulfillment_type == 'DELIVERY' && !DELIVERY_TIER_LABELS.key?(delivery_tier.to_s)
        render json: { error: "Invalid delivery tier. Must be next_day, two_day, or three_day" }, status: :unprocessable_entity
        return
      end
    elsif fulfillment_type == 'PICKUP'
      unless %w[normal after_hours].include?(pickup_variant)
        render json: { error: "Invalid pickup variant" }, status: :unprocessable_entity
        return
      end

      # Date/time only required for normal-hours pickup
      if pickup_variant == 'normal'
        if pickup_details.blank? || pickup_details[:date].blank? || pickup_details[:time].blank?
          render json: { error: "Pickup date and time are required for normal-hours pickup" }, status: :unprocessable_entity
          return
        end

        begin
          pickup_date = Date.parse(pickup_details[:date])
          if pickup_date < Date.today
            render json: { error: "Pickup date cannot be in the past" }, status: :unprocessable_entity
            return
          end
          if pickup_date.saturday? || pickup_date.sunday?
            render json: { error: "Pickup is not available on weekends. Please contact us for weekend arrangements." }, status: :unprocessable_entity
            return
          end
        rescue ArgumentError
          render json: { error: "Invalid pickup date format" }, status: :unprocessable_entity
          return
        end

        begin
          hour = pickup_details[:time].split(':')[0].to_i
          if hour < 8 || hour >= 17
            render json: { error: "Pickup time must be between 8:00 AM and 5:00 PM" }, status: :unprocessable_entity
            return
          end
        rescue
          render json: { error: "Invalid pickup time format" }, status: :unprocessable_entity
          return
        end
      end
    end

    square_service = SquareService.new

    # Find or create Square customer
    Rails.logger.info "Creating order for email: '#{customer_info[:email]}'"
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

      # Save address if provided for shipment or delivery
      address_relevant = %w[SHIPMENT DELIVERY].include?(fulfillment_type) && shipping_address.present?
      if address_relevant
        user_updates[:address_line_1] = shipping_address[:address_line_1] if shipping_address[:address_line_1].present?
        user_updates[:address_line_2] = shipping_address[:address_line_2] if shipping_address[:address_line_2].present?
        user_updates[:city] = shipping_address[:locality] if shipping_address[:locality].present?
        user_updates[:state] = shipping_address[:administrative_district_level_1] if shipping_address[:administrative_district_level_1].present?
        user_updates[:postal_code] = shipping_address[:postal_code] if shipping_address[:postal_code].present?
        user_updates[:country] = shipping_address[:country] || 'US'
      end

      current_user.update(user_updates) if user_updates.any?

      # Sync Square customer address (shipment + delivery)
      if address_relevant
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
      if pickup_variant == 'normal'
        pickup_datetime = DateTime.parse("#{pickup_details[:date]} #{pickup_details[:time]}")
        fulfillments << square_service.build_pickup_fulfillment(
          recipient_name: recipient_name,
          recipient_email: customer_info[:email],
          recipient_phone: current_user&.phone_number,
          pickup_at: pickup_datetime.iso8601,
          note: 'Normal-hours pickup. Please bring a valid ID.'
        )
      else
        fulfillments << square_service.build_pickup_fulfillment(
          recipient_name: recipient_name,
          recipient_email: customer_info[:email],
          recipient_phone: current_user&.phone_number,
          note: 'After-hours pickup — staff will contact the customer with instructions.'
        )
      end
    elsif fulfillment_type == 'DELIVERY'
      tier_label = DELIVERY_TIER_LABELS.fetch(delivery_tier.to_s)
      addr_line = "#{shipping_address[:address_line_1]} #{shipping_address[:address_line_2]}".strip
      delivery_note = "Delivery (#{tier_label}) to #{addr_line}, #{shipping_address[:locality]}, " \
                      "#{shipping_address[:administrative_district_level_1]} #{shipping_address[:postal_code]}. " \
                      "Pricing/coordination to follow."
      fulfillments << square_service.build_pickup_fulfillment(
        recipient_name: recipient_name,
        recipient_email: customer_info[:email],
        recipient_phone: current_user&.phone_number,
        note: delivery_note
      )
    elsif fulfillment_type == 'SHIPMENT'
      fulfillments << square_service.build_shipment_fulfillment(
        recipient_name: recipient_name,
        recipient_email: customer_info[:email],
        recipient_phone: current_user&.phone_number,
        address: shipping_address
      )
    end

    # Create the order with fulfillments. Auto-apply location-configured taxes on
    # every order — origin-sourced for shipments (single CO location).
    order_result = square_service.create_order(
      line_items: format_line_items(line_items),
      customer_id: square_customer_id,
      fulfillments: fulfillments,
      auto_apply_taxes: true
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

  # POST /api/orders/phone_call_request
  # Customer chose "request a phone call" at checkout. No payment, no Square order —
  # just email support@ with the cart so staff can follow up.
  def phone_call_request
    customer_info = params[:customer_info] || {}
    line_items = params[:line_items] || []
    notes = params[:notes].to_s

    if customer_info[:email].blank?
      render json: { error: "Email is required" }, status: :unprocessable_entity
      return
    end

    if line_items.empty?
      render json: { error: "Line items are required" }, status: :unprocessable_entity
      return
    end

    PhoneCallRequestMailer.support_notification(
      customer_info: customer_info.to_unsafe_h,
      line_items: line_items.map(&:to_unsafe_h),
      notes: notes
    ).deliver_later

    render json: { success: true, message: "Phone call request submitted. We'll be in touch shortly." }, status: :ok
  rescue StandardError => e
    Rails.logger.error("Phone call request error: #{e.message}")
    render json: { error: "Failed to submit phone call request" }, status: :internal_server_error
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
