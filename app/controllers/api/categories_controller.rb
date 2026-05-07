class Api::CategoriesController < ApplicationController
  skip_before_action :authenticate_request

  # Square sales-channel ID for the public website. Categories must be published
  # to this channel in the Square dashboard to appear on the storefront.
  # TODO: move to Rails credentials / ENV before deploying to additional environments.
  WEBSITE_CHANNEL_ID = "CH_u4JfKYV3BnLWa1mqr5uimpJeWOnAmzB28DcLIQlQuYC".freeze

  def index
    square_service = SquareService.new
    result = square_service.list_categories

    # The service returns { objects: [...enriched with image_urls] }
    categories_data = result[:objects] || []

    # Only show top-level categories that are published to the website sales channel.
    visible_categories = categories_data.select do |category|
      channels = category.dig(:category_data, :channels) || []
      channels.include?(WEBSITE_CHANNEL_ID) &&
        category.dig(:category_data, :is_top_level) == true
    end

    categories = visible_categories.map do |category|
      {
        id: category[:id],
        name: category.dig(:category_data, :name),
        ordinal: category.dig(:category_data, :ordinal),
        image_urls: category[:image_urls] || [], # URLs ready to display
        is_top_level: category.dig(:category_data, :is_top_level),
        created_at: category[:created_at],
        updated_at: category[:updated_at]
      }
    end

    render json: { categories: categories }, status: :ok
  rescue SquareService::SquareError => e
    render json: { error: e.message }, status: :bad_request
  rescue StandardError => e
    render json: { error: "Failed to fetch categories: #{e.message}" }, status: :internal_server_error
  end

  def show
    square_service = SquareService.new
    result = square_service.get_category(params[:id])

    if result[:object]
      category = result[:object]
      formatted_category = {
        id: category[:id],
        name: category.dig(:category_data, :name),
        ordinal: category.dig(:category_data, :ordinal),
        image_urls: category[:image_urls] || [],
        is_top_level: category.dig(:category_data, :is_top_level),
        created_at: category[:created_at],
        updated_at: category[:updated_at]
      }

      render json: { category: formatted_category }, status: :ok
    else
      render json: { error: "Category not found" }, status: :not_found
    end
  rescue SquareService::SquareError => e
    render json: { error: e.message }, status: :bad_request
  rescue StandardError => e
    render json: { error: "Failed to fetch category: #{e.message}" }, status: :internal_server_error
  end
end
