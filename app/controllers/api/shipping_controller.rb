class Api::ShippingController < ApplicationController
  skip_before_action :authenticate_request, only: [:rates]

  # POST /api/shipping/rates
  def rates
    result = ShippingRateService.new(
      destination: rate_params[:destination].to_h,
      line_items: rate_params[:line_items].map(&:to_h)
    ).call

    render json: { rates: result }
  rescue ShippingRateService::MissingWeightError => e
    render json: { error: e.message, code: "missing_weight" },
           status: :unprocessable_entity
  rescue SquareService::SquareError => e
    Rails.logger.error "Square error fetching product data: #{e.message}"
    render json: { error: "Unable to fetch product data", code: "catalog_service_unavailable" },
           status: :bad_gateway
  rescue ShippoClient::Error => e
    Rails.logger.error "Shippo error: #{e.message}"
    render json: { error: "Unable to fetch shipping rates", code: "shipping_service_unavailable" },
           status: :bad_gateway
  end

  private

  def rate_params
    params.require(:shipping).permit(
      destination: [:street1, :street2, :city, :state, :zip, :country],
      line_items: [:square_catalog_object_id, :quantity]
    )
  end
end
