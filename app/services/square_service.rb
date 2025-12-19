class SquareService
  class SquareError < StandardError
    attr_reader :errors, :status_code

    def initialize(errors, status_code = nil)
      @errors = errors
      @status_code = status_code
      super(format_error_message(errors))
    end

    private

    def format_error_message(errors)
      return "Unknown Square API error" unless errors

      if errors.is_a?(Array)
        errors.map { |e| "#{e[:category]}: #{e[:detail]}" }.join(", ")
      else
        errors.to_s
      end
    end
  end

  def initialize
    @client = SQUARE_CLIENT
    @location_id = Rails.application.config.square[:location_id]
  end

  # ======================
  # CATALOG OPERATIONS
  # ======================

  # List all catalog items with pagination
  # @param types [Array<String>] Types of catalog objects (default: ['ITEM'])
  # @param limit [Integer] Number of items per page (max 1000)
  # @return [Hash] { items: Array, cursor: String }
  def list_catalog_items(types: ['ITEM'], limit: 100)
    response = @client.catalog.list(types: types)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Search catalog items by text query
  # @param query [String] Search query text
  # @param limit [Integer] Number of results
  # @param category_ids [Array<String>] Filter by category IDs
  # @return [Hash] { items: Array, cursor: String } with image_urls added to each item
  def search_catalog_items(query: nil, limit: 100, category_ids: [])
    body = {
      limit: limit
    }

    if query.present?
      body[:text_filter] = query
    end

    if category_ids.any?
      body[:category_ids] = category_ids
    end

    response = @client.catalog.search_items(**body)
    result = handle_response(response)

    # Enrich items with image URLs
    if result[:items]
      result[:items] = enrich_items_with_images(result[:items])
    end

    result
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get a specific catalog item by ID
  # @param item_id [String] The catalog item ID
  # @param include_related [Boolean] Include related objects
  # @return [Hash] The catalog item object with image_urls
  def get_catalog_item(item_id, include_related: false)
    response = @client.catalog.object.get(object_id: item_id, include_related_objects: include_related)
    result = handle_response(response)

    # Extract image URLs from related objects if available
    if include_related && result[:object]
      result[:object][:image_urls] = extract_image_urls(result[:related_objects] || [])

      # Also extract image URLs for variations if present
      variations = result[:object].dig(:item_data, :variations)
      if variations
        variations.each do |variation|
          variation[:image_urls] = extract_image_urls(result[:related_objects] || [])
        end
      end
    end

    result
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Search catalog objects with advanced filtering
  # @param types [Array<String>] Object types to search
  # @param query [Hash] Search query parameters
  # @return [Hash] Search results
  def search_catalog_objects(types: ['ITEM'], query: {})
    body = {
      object_types: types
    }

    body.merge!(query) if query.present?

    response = @client.catalog.search(**body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Batch retrieve multiple catalog objects
  # @param object_ids [Array<String>] Array of object IDs
  # @param include_related [Boolean] Include related objects
  # @return [Hash] { objects: Array, related_objects: Array }
  def batch_retrieve_catalog_objects(object_ids, include_related: false)
    body = {
      object_ids: object_ids,
      include_related_objects: include_related
    }

    response = @client.catalog.batch_get(**body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # List all categories in the catalog
  # @return [Hash] { objects: Array } with image_urls added to each category
  def list_categories
    response = @client.catalog.list(types: ['CATEGORY'])
    result = handle_response(response)

    # Enrich categories with image URLs
    if result[:objects]
      result[:objects] = enrich_categories_with_images(result[:objects])
    end

    result
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get a specific category by ID
  # @param category_id [String] The category ID
  # @return [Hash] The category object with image_urls
  def get_category(category_id)
    response = @client.catalog.object.get(object_id: category_id, include_related_objects: true)
    result = handle_response(response)

    # Extract image URLs from related objects
    if result[:object]
      result[:object][:image_urls] = extract_image_urls(result[:related_objects] || [])
    end

    result
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Search categories by name
  # @param name [String] Category name to search for
  # @return [Hash] { objects: Array } with image_urls added to each category
  def search_categories(name: nil)
    body = {
      object_types: ['CATEGORY']
    }

    if name.present?
      body[:query] = {
        text_query: {
          keywords: [name]
        }
      }
    end

    response = @client.catalog.search(**body)
    result = handle_response(response)

    # Enrich categories with image URLs
    if result[:objects]
      result[:objects] = enrich_categories_with_images(result[:objects])
    end

    result
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get items by category ID
  # @param category_id [String] The category ID to filter by
  # @param limit [Integer] Number of results
  # @return [Hash] { items: Array } with image_urls added to each item
  def get_items_by_category(category_id, limit: 100)
    body = {
      category_ids: [category_id],
      limit: limit
    }

    response = @client.catalog.search_items(**body)
    result = handle_response(response)

    # Enrich items with image URLs
    if result[:items]
      result[:items] = enrich_items_with_images(result[:items])
    end

    result
  rescue StandardError => e
    handle_standard_error(e)
  end

  # ======================
  # CUSTOMER OPERATIONS
  # ======================

  # Create a new customer
  # @param email [String] Customer email
  # @param given_name [String] First name
  # @param family_name [String] Last name
  # @param phone_number [String] Phone number
  # @param address [Hash] Address details
  # @return [Hash] The created customer object
  def create_customer(email:, given_name: nil, family_name: nil, phone_number: nil, address: nil)
    body = {
      idempotency_key: generate_idempotency_key,
      email_address: email
    }

    body[:given_name] = given_name if given_name.present?
    body[:family_name] = family_name if family_name.present?
    body[:phone_number] = phone_number if phone_number.present?
    body[:address] = address if address.present?

    response = @client.customers.create(**body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get a customer by ID
  # @param customer_id [String] The customer ID
  # @return [Hash] The customer object
  def get_customer(customer_id)
    response = @client.customers.get(customer_id: customer_id)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Search customers
  # @param query [Hash] Search parameters
  # @param limit [Integer] Number of results
  # @return [Hash] { customers: Array, cursor: String }
  def search_customers(query: {}, limit: 100)
    body = {
      limit: limit
    }

    body[:query] = query if query.present?

    response = @client.customers.search(**body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Update a customer
  # @param customer_id [String] The customer ID
  # @param attributes [Hash] Attributes to update
  # @return [Hash] The updated customer object
  def update_customer(customer_id, attributes)
    response = @client.customers.update(customer_id: customer_id, **attributes)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Delete a customer
  # @param customer_id [String] The customer ID
  # @return [Hash] Success response
  def delete_customer(customer_id)
    response = @client.customers.delete(customer_id: customer_id)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Find or create a customer by email
  # @param email [String] Customer email
  # @param given_name [String] Optional first name
  # @param family_name [String] Optional last name
  # @return [Hash] The customer object
  def find_or_create_customer(email:, given_name: nil, family_name: nil)
    # Search for existing customer by email
    search_result = search_customers(
      query: {
        filter: {
          email_address: {
            exact: email
          }
        }
      }
    )

    # Return existing customer if found
    if search_result[:customers]&.any?
      return search_result[:customers].first
    end

    # Create new customer if not found
    create_result = create_customer(
      email: email,
      given_name: given_name,
      family_name: family_name
    )

    create_result[:customer]
  rescue StandardError => e
    handle_standard_error(e)
  end

  # ======================
  # ORDER OPERATIONS
  # ======================

  # Create a new order
  # @param line_items [Array<Hash>] Array of line items
  # @param customer_id [String] Optional customer ID
  # @param location_id [String] Location ID (defaults to configured location)
  # @param taxes [Array<Hash>] Optional taxes
  # @param discounts [Array<Hash>] Optional discounts
  # @return [Hash] The created order object
  def create_order(line_items:, customer_id: nil, location_id: nil, taxes: [], discounts: [])
    order_location_id = location_id || @location_id

    raise ArgumentError, "Location ID is required" unless order_location_id

    body = {
      idempotency_key: generate_idempotency_key,
      order: {
        location_id: order_location_id,
        line_items: line_items
      }
    }

    body[:order][:customer_id] = customer_id if customer_id.present?
    body[:order][:taxes] = taxes if taxes.any?
    body[:order][:discounts] = discounts if discounts.any?

    response = @client.orders.create(**body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Calculate order totals without creating the order
  # @param order [Hash] Order object
  # @return [Hash] The calculated order with totals
  def calculate_order(order)
    response = @client.orders.calculate(order: order)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get an order by ID
  # @param order_id [String] The order ID
  # @return [Hash] The order object
  def get_order(order_id)
    response = @client.orders.get(order_id: order_id)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Update an existing order
  # @param order_id [String] The order ID
  # @param updates [Hash] Order updates
  # @return [Hash] The updated order object
  def update_order(order_id, updates)
    body = {
      order: updates
    }

    response = @client.orders.update(order_id: order_id, **body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Pay for an order
  # @param order_id [String] The order ID
  # @param payment_ids [Array<String>] Array of payment IDs
  # @return [Hash] The paid order object
  def pay_order(order_id, payment_ids)
    body = {
      idempotency_key: generate_idempotency_key,
      payment_ids: payment_ids
    }

    response = @client.orders.pay(order_id: order_id, **body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Search orders
  # @param query [Hash] Search query parameters
  # @param limit [Integer] Number of results
  # @return [Hash] { orders: Array, cursor: String }
  def search_orders(query: {}, limit: 100)
    body = {
      limit: limit
    }

    body[:query] = query if query.present?

    # Add location_ids if not specified in query
    if query[:location_ids].blank? && @location_id.present?
      body[:location_ids] = [@location_id]
    end

    response = @client.orders.search(**body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get all orders for a specific customer
  # @param customer_id [String] The Square customer ID
  # @param limit [Integer] Number of results
  # @return [Hash] { orders: Array, cursor: String }
  def get_customer_orders(customer_id, limit: 100)
    query = {
      filter: {
        customer_filter: {
          customer_ids: [customer_id]
        },
        state_filter: {
          states: ['COMPLETED', 'OPEN']
        }
      },
      sort: {
        sort_field: 'CREATED_AT',
        sort_order: 'DESC'
      }
    }

    search_orders(query: query, limit: limit)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # ======================
  # PAYMENT OPERATIONS
  # ======================

  # Create a payment
  # @param source_id [String] Payment source ID (card nonce, token, etc.)
  # @param amount_money [Hash] { amount: Integer, currency: String }
  # @param order_id [String] Optional order ID
  # @param customer_id [String] Optional customer ID
  # @return [Hash] The payment object
  def create_payment(source_id:, amount_money:, order_id: nil, customer_id: nil)
    body = {
      idempotency_key: generate_idempotency_key,
      source_id: source_id,
      amount_money: amount_money
    }

    body[:order_id] = order_id if order_id.present?
    body[:customer_id] = customer_id if customer_id.present?
    body[:location_id] = @location_id if @location_id.present?

    response = @client.payments.create(**body)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get payment by ID
  # @param payment_id [String] The payment ID
  # @return [Hash] The payment object
  def get_payment(payment_id)
    response = @client.payments.get(payment_id: payment_id)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # ======================
  # LOCATION OPERATIONS
  # ======================

  # List all locations
  # @return [Hash] { locations: Array }
  def list_locations
    response = @client.locations.list
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Get location by ID
  # @param location_id [String] The location ID
  # @return [Hash] The location object
  def get_location(location_id)
    response = @client.locations.get(location_id: location_id)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # ======================
  # CARDS API OPERATIONS
  # ======================

  # Create a card on file for a customer
  # @param customer_id [String] The Square customer ID
  # @param source_id [String] Payment token from Web Payments SDK or recent payment ID
  # @param billing_address [Hash] Optional billing address
  # @param cardholder_name [String] Optional cardholder name
  # @return [Hash] { card: Hash } The created card object
  def create_card(customer_id:, source_id:, billing_address: nil, cardholder_name: nil)
    card_params = {
      customer_id: customer_id
    }

    card_params[:billing_address] = billing_address if billing_address.present?
    card_params[:cardholder_name] = cardholder_name if cardholder_name.present?

    response = @client.cards.create(
      idempotency_key: generate_idempotency_key,
      source_id: source_id,
      card: card_params
    )
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # List cards on file for a customer
  # @param customer_id [String] The Square customer ID
  # @param cursor [String] Optional cursor for pagination
  # @param include_disabled [Boolean] Include disabled cards (default: false)
  # @return [Hash] { cards: Array, cursor: String }
  def list_customer_cards(customer_id:, cursor: nil, include_disabled: false)
    params = { customer_id: customer_id }
    params[:cursor] = cursor if cursor.present?
    params[:include_disabled] = include_disabled

    response = @client.cards.list(**params)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Retrieve a specific card by ID
  # @param card_id [String] The card ID
  # @return [Hash] { card: Hash } The card object
  def get_card(card_id:)
    response = @client.cards.get(card_id: card_id)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Disable a card on file
  # @param card_id [String] The card ID to disable
  # @return [Hash] { card: Hash } The disabled card object
  def disable_card(card_id:)
    response = @client.cards.disable(card_id: card_id)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  # Create a payment using a card on file
  # @param card_id [String] The card ID to charge
  # @param amount [Integer] Amount in cents
  # @param currency [String] Currency code (default: USD)
  # @param customer_id [String] Optional customer ID
  # @param reference_id [String] Optional reference ID
  # @param note [String] Optional note for the payment
  # @return [Hash] { payment: Hash } The payment object
  def charge_card_on_file(card_id:, amount:, currency: 'USD', customer_id: nil, reference_id: nil, note: nil)
    params = {
      source_id: card_id,
      idempotency_key: generate_idempotency_key,
      amount_money: {
        amount: amount,
        currency: currency
      }
    }

    params[:customer_id] = customer_id if customer_id.present?
    params[:reference_id] = reference_id if reference_id.present?
    params[:note] = note if note.present?

    response = @client.payments.create(**params)
    handle_response(response)
  rescue StandardError => e
    handle_standard_error(e)
  end

  private

  # Generate a unique idempotency key
  def generate_idempotency_key
    SecureRandom.uuid
  end

  # Handle successful API responses
  def handle_response(response)
    # In SDK v44.2, responses are objects with data, errors, etc.
    # Convert to hash for easier consumption
    response.to_h
  end

  # Handle standard errors from Square SDK v44.2
  def handle_standard_error(exception)
    # In SDK v44.2, errors are raised as StandardError with message
    error_message = exception.message
    raise SquareError.new([{ detail: error_message }], nil)
  end

  # Enrich category objects with image URLs
  # @param categories [Array<Hash>] Array of category objects
  # @return [Array<Hash>] Categories with image_urls added
  def enrich_categories_with_images(categories)
    return categories if categories.blank?

    # Collect all image IDs from all categories
    image_ids = categories.flat_map do |category|
      category.dig(:category_data, :image_ids) || []
    end.compact.uniq

    return categories if image_ids.empty?

    # Batch fetch all images
    images_response = batch_retrieve_catalog_objects(image_ids)
    image_map = {}

    # Build a map of image_id => url
    if images_response[:objects]
      images_response[:objects].each do |image_obj|
        if image_obj[:type] == 'IMAGE' && image_obj.dig(:image_data, :url)
          image_map[image_obj[:id]] = image_obj[:image_data][:url]
        end
      end
    end

    # Add image_urls to each category
    categories.map do |category|
      category_image_ids = category.dig(:category_data, :image_ids) || []
      category[:image_urls] = category_image_ids.map { |id| image_map[id] }.compact
      category
    end
  end

  # Extract image URLs from related objects
  # @param related_objects [Array<Hash>] Related objects from Square API
  # @return [Array<String>] Array of image URLs
  def extract_image_urls(related_objects)
    return [] if related_objects.blank?

    related_objects
      .select { |obj| obj[:type] == 'IMAGE' }
      .map { |obj| obj.dig(:image_data, :url) }
      .compact
  end

  # Enrich item objects with image URLs
  # @param items [Array<Hash>] Array of item objects
  # @return [Array<Hash>] Items with image_urls added
  def enrich_items_with_images(items)
    return items if items.blank?

    # Collect all image IDs from items and their variations
    image_ids = items.flat_map do |item|
      item_image_ids = item.dig(:item_data, :image_ids) || []
      variation_image_ids = (item.dig(:item_data, :variations) || []).flat_map do |variation|
        variation.dig(:item_variation_data, :image_ids) || []
      end
      item_image_ids + variation_image_ids
    end.compact.uniq

    return items if image_ids.empty?

    # Batch fetch all images
    images_response = batch_retrieve_catalog_objects(image_ids)
    image_map = {}

    # Build a map of image_id => url
    if images_response[:objects]
      images_response[:objects].each do |image_obj|
        if image_obj[:type] == 'IMAGE' && image_obj.dig(:image_data, :url)
          image_map[image_obj[:id]] = image_obj[:image_data][:url]
        end
      end
    end

    # Add image_urls to each item and its variations
    items.map do |item|
      # Add image URLs to the item
      item_image_ids = item.dig(:item_data, :image_ids) || []
      item[:image_urls] = item_image_ids.map { |id| image_map[id] }.compact

      # Add image URLs to variations
      if item.dig(:item_data, :variations)
        item[:item_data][:variations].each do |variation|
          variation_image_ids = variation.dig(:item_variation_data, :image_ids) || []
          variation[:image_urls] = variation_image_ids.map { |id| image_map[id] }.compact
        end
      end

      item
    end
  end
end
