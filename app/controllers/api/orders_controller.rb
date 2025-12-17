class Api::OrdersController < ApplicationController
  skip_before_action :authenticate_request, only: [:calculate]
  before_action :authenticate_request, only: [:create]

  # POST /api/orders/calculate
  # Calculate order totals without creating the order
  def calculate
    line_items = params[:line_items]

    unless line_items.present?
      render json: { error: "Line items are required" }, status: :unprocessable_entity
      return
    end

    # Build order object for Square
    order = {
      location_id: Rails.application.config.square[:location_id],
      line_items: format_line_items(line_items)
    }

    square_service = SquareService.new
    result = square_service.calculate_order(order)

    if result[:order]
      render json: format_calculated_order(result[:order]), status: :ok
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

    # Validate required params
    unless line_items.present? && payment_token.present? && customer_info.present?
      render json: { error: "Line items, payment token, and customer info are required" }, status: :unprocessable_entity
      return
    end

    square_service = SquareService.new

    # Find or create Square customer
    customer = square_service.find_or_create_customer(
      email: customer_info[:email],
      given_name: customer_info[:given_name],
      family_name: customer_info[:family_name]
    )

    square_customer_id = customer[:id]

    # Update current user with Square customer ID if not already set
    if current_user && current_user.square_customer_id.blank?
      current_user.update(square_customer_id: square_customer_id)
    end

    # Create the order
    order_result = square_service.create_order(
      line_items: format_line_items(line_items),
      customer_id: square_customer_id
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
