require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ShippoClient, type: :service do
  let(:client) { described_class.new }
  let(:shippo_url) { "https://api.goshippo.com/shipments/" }
  let(:payload) do
    {
      address_from: { street1: "123 Warehouse Way", city: "Fort Collins", state: "CO", zip: "80521", country: "US" },
      address_to: { street1: "456 Main St", city: "Denver", state: "CO", zip: "80202", country: "US" },
      parcels: [{ length: 12, width: 8, height: 6, distance_unit: "in", weight: 5, mass_unit: "lb" }],
      async: false
    }
  end

  describe '#create_shipment' do
    it 'returns parsed response on success' do
      stub_request(:post, shippo_url)
        .to_return(status: 200, body: { "rates" => [{ "provider" => "UPS" }] }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.create_shipment(payload)
      expect(result["rates"]).to be_an(Array)
    end

    it 'sends correct authorization header' do
      stub_request(:post, shippo_url)
        .to_return(status: 200, body: { "rates" => [] }.to_json, headers: { 'Content-Type' => 'application/json' })

      client.create_shipment(payload)

      expect(WebMock).to have_requested(:post, shippo_url)
        .with(headers: { 'Authorization' => /^ShippoToken/ })
    end

    it 'sends JSON content type' do
      stub_request(:post, shippo_url)
        .to_return(status: 200, body: { "rates" => [] }.to_json, headers: { 'Content-Type' => 'application/json' })

      client.create_shipment(payload)

      expect(WebMock).to have_requested(:post, shippo_url)
        .with(headers: { 'Content-Type' => 'application/json' })
    end

    it 'raises AuthError on 401' do
      stub_request(:post, shippo_url).to_return(status: 401, body: "Unauthorized")

      expect { client.create_shipment(payload) }.to raise_error(ShippoClient::AuthError)
    end

    it 'raises AuthError on 403' do
      stub_request(:post, shippo_url).to_return(status: 403, body: "Forbidden")

      expect { client.create_shipment(payload) }.to raise_error(ShippoClient::AuthError)
    end

    it 'raises RateError on 400' do
      stub_request(:post, shippo_url).to_return(status: 400, body: "Bad Request")

      expect { client.create_shipment(payload) }.to raise_error(ShippoClient::RateError)
    end

    it 'raises Error on 500' do
      stub_request(:post, shippo_url).to_return(status: 500, body: "Internal Server Error")

      expect { client.create_shipment(payload) }.to raise_error(ShippoClient::Error)
    end

    it 'raises TimeoutError on timeout' do
      stub_request(:post, shippo_url).to_timeout

      expect { client.create_shipment(payload) }.to raise_error(ShippoClient::TimeoutError)
    end
  end
end
