class ShippingRateService
  class MissingWeightError < StandardError; end

  # Default parcel dimensions (inches) when Square doesn't provide them.
  # Adjust these to match your typical shipping box.
  DEFAULT_PARCEL = { length: 16, width: 12, height: 12, distance_unit: "in" }.freeze

  def initialize(destination:, line_items:)
    @destination = destination
    @line_items = line_items # [{ square_catalog_object_id:, quantity: }, ...]
  end

  def call
    parcel = build_parcel
    payload = {
      address_from: origin_address,
      address_to: @destination,
      parcels: [parcel],
      async: false
    }
    response = ShippoClient.new.create_shipment(payload)
    filter_ups_rates(response["rates"] || [])
  end

  private

  def origin_address
    Rails.application.credentials.shipping_origin.to_h
  end

  def build_parcel
    catalog_data = fetch_catalog_data
    total_weight = calculate_total_weight(catalog_data)

    DEFAULT_PARCEL.merge(
      weight: total_weight,
      mass_unit: "lb"
    )
  end

  def fetch_catalog_data
    object_ids = @line_items.map { |li| li[:square_catalog_object_id] }.compact.uniq
    return {} if object_ids.empty?

    square_service = SquareService.new
    result = square_service.batch_retrieve_catalog_objects(object_ids, include_related: true)

    # When the caller passes a variation ID, Square returns the variation in :objects
    # and its parent ITEM in :related_objects. We need both to find weights that may
    # be set as custom attributes on either level.
    all_objects = (result[:objects] || []) + (result[:related_objects] || [])
    all_objects.index_by { |obj| obj[:id] }
  end

  def calculate_total_weight(catalog_data)
    total = 0.0

    @line_items.each do |item|
      id = item[:square_catalog_object_id]
      quantity = (item[:quantity] || 1).to_i
      catalog_obj = catalog_data[id]

      weight = extract_weight(catalog_obj, catalog_data, id)
      total += weight * quantity
    end

    total
  end

  def extract_weight(catalog_obj, catalog_data, catalog_id)
    return raise_missing_weight(catalog_id) unless catalog_obj

    # 1. Variation/item's own custom attributes
    weight = extract_weight_from_custom_attributes(catalog_obj)
    return weight if weight

    # 2. If we have a variation, check its parent item's custom attributes
    parent_item_id = catalog_obj.dig(:item_variation_data, :item_id)
    if parent_item_id
      parent_item = catalog_data[parent_item_id]
      weight = extract_weight_from_custom_attributes(parent_item) if parent_item
      return weight if weight
    end

    # 3. If we have an item, walk its variations' custom attributes
    item_data = catalog_obj.dig(:item_data)
    if item_data
      variations = item_data[:variations] || []
      variations.each do |v|
        weight = extract_weight_from_custom_attributes(v)
        return weight if weight
      end
    end

    Rails.logger.error "No weight found for catalog object #{catalog_id}. Object keys: #{catalog_obj.keys}. " \
      "custom_attribute_values: #{catalog_obj[:custom_attribute_values]&.keys}. " \
      "Parent item id: #{parent_item_id.inspect}."
    raise_missing_weight(catalog_id)
  end

  def extract_weight_from_custom_attributes(obj)
    custom_attrs = obj[:custom_attribute_values]
    return nil unless custom_attrs.is_a?(Hash)

    # Search for any custom attribute whose key contains "weight" (case-insensitive)
    custom_attrs.each do |key, value|
      next unless key.to_s.downcase.include?("weight")

      # Custom attributes can have string_value or number_value
      w = value[:number_value] || value[:string_value]
      return w.to_f if w.present? && w.to_f > 0
    end

    nil
  end

  def raise_missing_weight(catalog_id)
    raise MissingWeightError,
      "No weight found for catalog object: #{catalog_id}. " \
      "Please set weight on the item variation in Square."
  end

  def filter_ups_rates(rates)
    rates.select { |r| r["provider"] == "UPS" }
  end
end
