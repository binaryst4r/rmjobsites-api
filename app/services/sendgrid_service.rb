require 'sendgrid-ruby'
include SendGrid

class SendgridService
  class SendgridError < StandardError
    attr_reader :response

    def initialize(message, response = nil)
      @response = response
      super(message)
    end
  end

  def initialize
    @api_key = Rails.application.config.sendgrid[:api_key]
    @from_email = Rails.application.config.sendgrid[:from_email]
    @from_name = Rails.application.config.sendgrid[:from_name]
  end

  # Send order confirmation email
  # @param order [Hash] Square order object
  # @param payment [Hash] Square payment object
  # @param customer [Hash] Square customer object
  # @param fulfillment_type [String] 'PICKUP' or 'SHIPMENT'
  # @return [Boolean] true if email sent successfully
  def send_order_confirmation(order:, payment:, customer:, fulfillment_type: 'PICKUP')
    unless @api_key.present?
      Rails.logger.warn "SendGrid API key not configured - skipping email"
      return false
    end

    begin
      email = build_order_confirmation_email(
        order: order,
        payment: payment,
        customer: customer,
        fulfillment_type: fulfillment_type
      )

      sg = SendGrid::API.new(api_key: @api_key)
      response = sg.client.mail._('send').post(request_body: email)

      if response.status_code.to_i >= 200 && response.status_code.to_i < 300
        Rails.logger.info "Order confirmation email sent successfully to #{customer[:email_address]} for order #{order[:id]}"
        true
      else
        Rails.logger.error "SendGrid API returned error: #{response.status_code} - #{response.body}"
        raise SendgridError.new("SendGrid returned status #{response.status_code}", response)
      end
    rescue StandardError => e
      Rails.logger.error "Failed to send order confirmation email: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  private

  def build_order_confirmation_email(order:, payment:, customer:, fulfillment_type:)
    from = SendGrid::Email.new(email: @from_email, name: @from_name)
    to = SendGrid::Email.new(email: customer[:email_address])
    subject = "Order Confirmation ##{order[:id]}"

    # Build HTML content
    html_content = build_html_content(
      order: order,
      payment: payment,
      customer: customer,
      fulfillment_type: fulfillment_type
    )

    # Build plain text content
    text_content = build_text_content(
      order: order,
      payment: payment,
      customer: customer,
      fulfillment_type: fulfillment_type
    )

    content_html = SendGrid::Content.new(type: 'text/html', value: html_content)
    content_text = SendGrid::Content.new(type: 'text/plain', value: text_content)

    mail = SendGrid::Mail.new(from, subject, to, content_text)
    mail.add_content(content_html)

    mail.to_json
  end

  def build_html_content(order:, payment:, customer:, fulfillment_type:)
    customer_name = "#{customer[:given_name]} #{customer[:family_name]}".strip
    customer_name = customer[:email_address] if customer_name.blank?

    fulfillment = order[:fulfillments]&.first
    pickup_details = fulfillment&.dig(:pickup_details)
    shipment_details = fulfillment&.dig(:shipment_details)

    # Build line items table
    line_items_html = order[:line_items]&.map do |item|
      "<tr>
        <td style='padding: 12px; border-bottom: 1px solid #e5e7eb;'>#{item[:name]}</td>
        <td style='padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: center;'>#{item[:quantity]}</td>
        <td style='padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: right;'>#{format_money(item[:total_money])}</td>
      </tr>"
    end&.join

    # Build fulfillment details
    fulfillment_html = if fulfillment_type == 'PICKUP' && pickup_details
      pickup_time = pickup_details[:pickup_at] ? format_pickup_time(pickup_details[:pickup_at]) : 'TBD'
      "<div style='background-color: #f3f4f6; padding: 16px; border-radius: 8px; margin: 20px 0;'>
        <h3 style='margin-top: 0; color: #374151;'>Pickup Information</h3>
        <p style='margin: 8px 0;'><strong>Location:</strong><br/>
        7204 E 53rd Pl<br/>
        Commerce City, CO 80022</p>
        <p style='margin: 8px 0;'><strong>Scheduled Pickup:</strong> #{pickup_time}</p>
        <p style='margin: 8px 0; color: #6b7280; font-size: 14px;'>#{pickup_details[:note]}</p>
      </div>"
    elsif fulfillment_type == 'SHIPMENT' && shipment_details
      address = shipment_details.dig(:recipient, :address)
      recipient_name = shipment_details.dig(:recipient, :display_name)
      address_html = if address
        lines = [address[:address_line_1], address[:address_line_2]].compact
        city_state_zip = [address[:locality], address[:administrative_district_level_1], address[:postal_code]].compact.join(', ')
        "#{lines.join('<br/>')}<br/>#{city_state_zip}"
      else
        'Address not provided'
      end

      "<div style='background-color: #f3f4f6; padding: 16px; border-radius: 8px; margin: 20px 0;'>
        <h3 style='margin-top: 0; color: #374151;'>Shipping Information</h3>
        <p style='margin: 8px 0;'><strong>Ship To:</strong><br/>
        #{recipient_name}<br/>
        #{address_html}</p>
      </div>"
    else
      ''
    end

    # Build payment info
    payment_info = if payment && payment[:card_details]
      card = payment[:card_details][:card]
      "#{card[:card_brand]} ending in #{card[:last_4]}"
    else
      'Card on file'
    end

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Order Confirmation</title>
      </head>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #374151; max-width: 600px; margin: 0 auto; padding: 20px;">

        <div style="text-align: center; margin-bottom: 30px;">
          <h1 style="color: #111827; margin-bottom: 8px;">Thank You for Your Order!</h1>
          <p style="color: #6b7280; margin: 0;">Order ##{order[:id]}</p>
        </div>

        <div style="background-color: #f9fafb; padding: 20px; border-radius: 8px; margin-bottom: 24px;">
          <p style="margin: 0 0 8px 0;">Hi #{customer_name},</p>
          <p style="margin: 0;">We've received your order and will process it shortly. You'll receive another email when your order has been #{fulfillment_type == 'PICKUP' ? 'prepared for pickup' : 'shipped'}.</p>
        </div>

        #{fulfillment_html}

        <h2 style="color: #374151; border-bottom: 2px solid #e5e7eb; padding-bottom: 8px;">Order Summary</h2>

        <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
          <thead>
            <tr style="background-color: #f9fafb;">
              <th style="padding: 12px; text-align: left; border-bottom: 2px solid #e5e7eb;">Item</th>
              <th style="padding: 12px; text-align: center; border-bottom: 2px solid #e5e7eb;">Qty</th>
              <th style="padding: 12px; text-align: right; border-bottom: 2px solid #e5e7eb;">Price</th>
            </tr>
          </thead>
          <tbody>
            #{line_items_html}
          </tbody>
        </table>

        <div style="margin: 24px 0; padding: 16px; background-color: #f9fafb; border-radius: 8px;">
          <div style="display: flex; justify-content: space-between; margin: 8px 0;">
            <span>Subtotal:</span>
            <span>#{format_money(order[:total_line_items_money])}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin: 8px 0;">
            <span>Tax:</span>
            <span>#{format_money(order[:total_tax_money])}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin: 8px 0;">
            <span>Shipping:</span>
            <span>#{format_money(order[:total_service_charge_money])}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin: 16px 0 0 0; padding-top: 12px; border-top: 2px solid #e5e7eb; font-size: 18px; font-weight: bold;">
            <span>Total:</span>
            <span>#{format_money(order[:total_money])}</span>
          </div>
        </div>

        <div style="background-color: #f3f4f6; padding: 16px; border-radius: 8px; margin: 20px 0;">
          <p style="margin: 0 0 8px 0;"><strong>Payment Method:</strong> #{payment_info}</p>
          <p style="margin: 0;"><strong>Order Date:</strong> #{format_order_date(order[:created_at])}</p>
        </div>

        <div style="margin-top: 32px; padding-top: 20px; border-top: 1px solid #e5e7eb; text-align: center; color: #6b7280; font-size: 14px;">
          <p>Questions about your order? Contact us at <a href="mailto:support@rmjobsites.com" style="color: #2563eb;">support@rmjobsites.com</a></p>
          <p style="margin-top: 16px;">&copy; #{Time.current.year} RM Jobsites. All rights reserved.</p>
        </div>

      </body>
      </html>
    HTML
  end

  def build_text_content(order:, payment:, customer:, fulfillment_type:)
    customer_name = "#{customer[:given_name]} #{customer[:family_name]}".strip
    customer_name = customer[:email_address] if customer_name.blank?

    fulfillment = order[:fulfillments]&.first
    pickup_details = fulfillment&.dig(:pickup_details)
    shipment_details = fulfillment&.dig(:shipment_details)

    # Build line items
    line_items_text = order[:line_items]&.map do |item|
      "#{item[:name]} (Qty: #{item[:quantity]}) - #{format_money(item[:total_money])}"
    end&.join("\n")

    # Build fulfillment details
    fulfillment_text = if fulfillment_type == 'PICKUP' && pickup_details
      pickup_time = pickup_details[:pickup_at] ? format_pickup_time(pickup_details[:pickup_at]) : 'TBD'
      "\nPICKUP INFORMATION\n" +
      "==================\n" +
      "Location:\n7204 E 53rd Pl\nCommerce City, CO 80022\n\n" +
      "Scheduled Pickup: #{pickup_time}\n" +
      "#{pickup_details[:note]}\n"
    elsif fulfillment_type == 'SHIPMENT' && shipment_details
      address = shipment_details.dig(:recipient, :address)
      recipient_name = shipment_details.dig(:recipient, :display_name)
      address_text = if address
        lines = [address[:address_line_1], address[:address_line_2]].compact.join("\n")
        city_state_zip = [address[:locality], address[:administrative_district_level_1], address[:postal_code]].compact.join(', ')
        "#{lines}\n#{city_state_zip}"
      else
        'Address not provided'
      end

      "\nSHIPPING INFORMATION\n" +
      "====================\n" +
      "Ship To:\n#{recipient_name}\n#{address_text}\n"
    else
      ''
    end

    # Build payment info
    payment_info = if payment && payment[:card_details]
      card = payment[:card_details][:card]
      "#{card[:card_brand]} ending in #{card[:last_4]}"
    else
      'Card on file'
    end

    <<~TEXT
      THANK YOU FOR YOUR ORDER!

      Order ##{order[:id]}

      Hi #{customer_name},

      We've received your order and will process it shortly. You'll receive another email when your order has been #{fulfillment_type == 'PICKUP' ? 'prepared for pickup' : 'shipped'}.

      #{fulfillment_text}

      ORDER SUMMARY
      =============

      #{line_items_text}

      Subtotal: #{format_money(order[:total_line_items_money])}
      Tax: #{format_money(order[:total_tax_money])}
      Shipping: #{format_money(order[:total_service_charge_money])}
      ----------------------------------
      Total: #{format_money(order[:total_money])}

      PAYMENT & ORDER INFO
      ====================
      Payment Method: #{payment_info}
      Order Date: #{format_order_date(order[:created_at])}

      Questions about your order? Contact us at support@rmjobsites.com

      © #{Time.current.year} RM Jobsites. All rights reserved.
    TEXT
  end

  def format_money(money_hash)
    return '$0.00' if money_hash.nil?
    amount = money_hash[:amount] || 0
    currency = money_hash[:currency] || 'USD'
    "$#{'%.2f' % (amount / 100.0)}"
  end

  def format_order_date(date_string)
    return '' if date_string.nil?
    DateTime.parse(date_string).strftime('%B %d, %Y at %I:%M %p')
  rescue
    date_string
  end

  def format_pickup_time(iso_string)
    return '' if iso_string.nil?
    DateTime.parse(iso_string).strftime('%A, %B %d, %Y at %I:%M %p')
  rescue
    iso_string
  end
end
