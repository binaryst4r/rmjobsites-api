require 'rails_helper'

RSpec.describe ShippingRateService, type: :service do
  let(:destination) do
    { street1: "456 Main St", city: "Denver", state: "CO", zip: "80202", country: "US" }
  end

  let(:square_service) { instance_double(SquareService) }

  let(:catalog_objects) do
    {
      objects: [
        {
          id: "VAR_A",
          type: "ITEM_VARIATION",
          item_variation_data: { name: "Default" },
          custom_attribute_values: { "Weight" => { string_value: "5.0" } }
        },
        {
          id: "VAR_B",
          type: "ITEM_VARIATION",
          item_variation_data: { name: "Large" },
          custom_attribute_values: { "Weight" => { string_value: "10.0" } }
        }
      ]
    }
  end

  let(:shippo_response) do
    {
      "rates" => [
        { "provider" => "UPS", "servicelevel" => { "name" => "Ground" }, "amount" => "12.50" },
        { "provider" => "UPS", "servicelevel" => { "name" => "Next Day Air" }, "amount" => "45.00" },
        { "provider" => "USPS", "servicelevel" => { "name" => "Priority" }, "amount" => "8.00" }
      ]
    }
  end

  before do
    allow(SquareService).to receive(:new).and_return(square_service)
    allow(square_service).to receive(:batch_retrieve_catalog_objects).and_return(catalog_objects)
    allow_any_instance_of(ShippoClient).to receive(:create_shipment).and_return(shippo_response)
  end

  describe '#call' do
    it 'returns only UPS rates' do
      service = described_class.new(
        destination: destination,
        line_items: [{ square_catalog_object_id: "VAR_A", quantity: 1 }]
      )
      rates = service.call
      expect(rates.length).to eq(2)
      expect(rates.all? { |r| r["provider"] == "UPS" }).to be true
    end

    it 'sums weight across line items and quantities' do
      service = described_class.new(
        destination: destination,
        line_items: [
          { square_catalog_object_id: "VAR_A", quantity: 2 },
          { square_catalog_object_id: "VAR_B", quantity: 1 }
        ]
      )

      expect_any_instance_of(ShippoClient).to receive(:create_shipment) do |_client, payload|
        parcel = payload[:parcels].first
        expect(parcel[:weight]).to eq(20.0) # 5.0*2 + 10.0*1
        expect(parcel[:mass_unit]).to eq("lb")
        expect(parcel[:distance_unit]).to eq("in")
        shippo_response
      end

      service.call
    end

    it 'uses default parcel dimensions' do
      service = described_class.new(
        destination: destination,
        line_items: [{ square_catalog_object_id: "VAR_A", quantity: 1 }]
      )

      expect_any_instance_of(ShippoClient).to receive(:create_shipment) do |_client, payload|
        parcel = payload[:parcels].first
        expect(parcel[:length]).to eq(16)
        expect(parcel[:width]).to eq(12)
        expect(parcel[:height]).to eq(12)
        shippo_response
      end

      service.call
    end

    it 'fetches catalog objects from Square' do
      service = described_class.new(
        destination: destination,
        line_items: [
          { square_catalog_object_id: "VAR_A", quantity: 1 },
          { square_catalog_object_id: "VAR_B", quantity: 1 }
        ]
      )

      expect(square_service).to receive(:batch_retrieve_catalog_objects)
        .with(["VAR_A", "VAR_B"], include_related: true)
        .and_return(catalog_objects)

      service.call
    end

    it 'raises MissingWeightError when catalog object has no weight' do
      allow(square_service).to receive(:batch_retrieve_catalog_objects).and_return({
        objects: [
          { id: "VAR_NO_WEIGHT", type: "ITEM_VARIATION", item_variation_data: { name: "No Weight" } }
        ]
      })

      service = described_class.new(
        destination: destination,
        line_items: [{ square_catalog_object_id: "VAR_NO_WEIGHT", quantity: 1 }]
      )

      expect { service.call }.to raise_error(
        ShippingRateService::MissingWeightError,
        /VAR_NO_WEIGHT/
      )
    end

    it 'raises MissingWeightError when catalog object not found' do
      allow(square_service).to receive(:batch_retrieve_catalog_objects).and_return({ objects: [] })

      service = described_class.new(
        destination: destination,
        line_items: [{ square_catalog_object_id: "UNKNOWN_ID", quantity: 1 }]
      )

      expect { service.call }.to raise_error(
        ShippingRateService::MissingWeightError,
        /UNKNOWN_ID/
      )
    end

    it 'returns empty array when no UPS rates exist' do
      allow_any_instance_of(ShippoClient).to receive(:create_shipment).and_return({
        "rates" => [{ "provider" => "USPS", "amount" => "8.00" }]
      })

      service = described_class.new(
        destination: destination,
        line_items: [{ square_catalog_object_id: "VAR_A", quantity: 1 }]
      )

      expect(service.call).to eq([])
    end
  end
end
