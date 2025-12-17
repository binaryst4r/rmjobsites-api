class Api::ProductsController < ApplicationController
  skip_before_action :authenticate_request

  # GET /api/products
  # Optional params: query (text search), category_ids (comma-separated)
  def index
    square_service = SquareService.new

    query = params[:query]
    category_ids = params[:category_ids]&.split(',') || []
    limit = params[:limit]&.to_i || 100

    result = square_service.search_catalog_items(
      query: query,
      category_ids: category_ids,
      limit: limit
    )

    products = format_products(result[:items] || [])
    render json: { products: products }, status: :ok
  rescue SquareService::SquareError => e
    render json: { error: e.message }, status: :bad_request
  rescue StandardError => e
    render json: { error: "Failed to fetch products: #{e.message}" }, status: :internal_server_error
  end

  # GET /api/products/:id
  def show
    square_service = SquareService.new
    result = square_service.get_catalog_item(params[:id], include_related: true)

    if result[:object]
      product = format_product(result[:object])
      render json: { product: product }, status: :ok
    else
      render json: { error: "Product not found" }, status: :not_found
    end
  rescue SquareService::SquareError => e
    render json: { error: e.message }, status: :bad_request
  rescue StandardError => e
    render json: { error: "Failed to fetch product: #{e.message}" }, status: :internal_server_error
  end

  # GET /api/categories/:category_id/products
  def by_category
    square_service = SquareService.new
    limit = params[:limit]&.to_i || 100

    result = square_service.get_items_by_category(params[:id], limit: limit)

    products = format_products(result[:items] || [])
    render json: { products: products }, status: :ok
  rescue SquareService::SquareError => e
    render json: { error: e.message }, status: :bad_request
  rescue StandardError => e
    render json: { error: "Failed to fetch products by category: #{e.message}" }, status: :internal_server_error
  end

  private

  def format_products(items)
    items.map { |item| format_product(item) }
  end

  def format_product(item)
    {
      id: item[:id],
      name: item.dig(:item_data, :name),
      description: item.dig(:item_data, :description),
      abbreviation: item.dig(:item_data, :abbreviation),
      category_ids: item.dig(:item_data, :category_ids) || [],
      image_urls: item[:image_urls] || [],
      variations: format_variations(item.dig(:item_data, :variations) || []),
      product_type: item.dig(:item_data, :product_type),
      available_online: item.dig(:item_data, :available_online),
      available_for_pickup: item.dig(:item_data, :available_for_pickup),
      created_at: item[:created_at],
      updated_at: item[:updated_at]
    }
  end

  def format_variations(variations)
    variations.map do |variation|
      {
        id: variation[:id],
        name: variation.dig(:item_variation_data, :name),
        sku: variation.dig(:item_variation_data, :sku),
        price_money: variation.dig(:item_variation_data, :price_money),
        pricing_type: variation.dig(:item_variation_data, :pricing_type),
        image_urls: variation[:image_urls] || [],
        ordinal: variation.dig(:item_variation_data, :ordinal),
        available_for_booking: variation.dig(:item_variation_data, :available_for_booking)
      }
    end
  end
end
