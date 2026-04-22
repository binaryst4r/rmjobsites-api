require 'rails_helper'

RSpec.describe "Shipping API", type: :request do
  let(:valid_params) do
    {
      shipping: {
        destination: {
          street1: "456 Main St",
          city: "Denver",
          state: "CO",
          zip: "80202",
          country: "US"
        },
        line_items: [
          { square_catalog_object_id: "VAR_A", quantity: 1 }
        ]
      }
    }
  end

  let(:ups_rates) do
    [
      { "provider" => "UPS", "servicelevel" => { "name" => "Ground" }, "amount" => "12.50" }
    ]
  end

  describe "POST /api/shipping/rates" do
    context "when successful" do
      before do
        allow_any_instance_of(ShippingRateService).to receive(:call).and_return(ups_rates)
      end

      it "returns UPS rates" do
        post "/api/shipping/rates", params: valid_params, as: :json
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["rates"]).to be_an(Array)
        expect(body["rates"].first["provider"]).to eq("UPS")
      end

      it "does not require authentication" do
        post "/api/shipping/rates", params: valid_params, as: :json
        expect(response).not_to have_http_status(:unauthorized)
      end
    end

    context "when product weight is missing" do
      before do
        allow_any_instance_of(ShippingRateService).to receive(:call)
          .and_raise(ShippingRateService::MissingWeightError, "No weight found for catalog object: MISSING_ID")
      end

      it "returns 422 with error details" do
        post "/api/shipping/rates", params: valid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["code"]).to eq("missing_weight")
        expect(body["error"]).to include("MISSING_ID")
      end
    end

    context "when Shippo is unavailable" do
      before do
        allow_any_instance_of(ShippingRateService).to receive(:call)
          .and_raise(ShippoClient::Error, "Shippo server error")
      end

      it "returns 502" do
        post "/api/shipping/rates", params: valid_params, as: :json
        expect(response).to have_http_status(:bad_gateway)
        body = JSON.parse(response.body)
        expect(body["code"]).to eq("shipping_service_unavailable")
      end
    end

    context "when Square catalog is unavailable" do
      before do
        allow_any_instance_of(ShippingRateService).to receive(:call)
          .and_raise(SquareService::SquareError.new([{ detail: "Service unavailable" }]))
      end

      it "returns 502" do
        post "/api/shipping/rates", params: valid_params, as: :json
        expect(response).to have_http_status(:bad_gateway)
        body = JSON.parse(response.body)
        expect(body["code"]).to eq("catalog_service_unavailable")
      end
    end
  end
end
