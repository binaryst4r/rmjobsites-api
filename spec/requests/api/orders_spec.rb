require "rails_helper"

RSpec.describe "Api::Orders", type: :request do
  let(:square_service) { instance_double(SquareService) }
  let(:line_items) { [{ catalog_object_id: "CATALOG_ITEM_1", quantity: "2" }] }

  before do
    allow(SquareService).to receive(:new).and_return(square_service)
  end

  describe "POST /api/orders/calculate" do
    let(:calculated_order) do
      {
        order: {
          line_items: [{ total_money: { amount: 1000 } }],
          total_tax_money: { amount: 85 },
          total_money: { amount: 1085 }
        }
      }
    end

    it "passes auto_apply_taxes pricing option for PICKUP orders" do
      expect(square_service).to receive(:calculate_order) do |order|
        expect(order[:pricing_options]).to eq(auto_apply_taxes: true)
        calculated_order
      end

      post "/api/orders/calculate", params: { line_items: line_items, fulfillment_type: "PICKUP" }
      expect(response).to have_http_status(:ok)
    end

    it "also auto-applies taxes for SHIPMENT orders (origin-sourced)" do
      expect(square_service).to receive(:calculate_order) do |order|
        expect(order[:pricing_options]).to eq(auto_apply_taxes: true)
        calculated_order
      end

      post "/api/orders/calculate", params: { line_items: line_items, fulfillment_type: "SHIPMENT" }
      expect(response).to have_http_status(:ok)
    end
  end
end
