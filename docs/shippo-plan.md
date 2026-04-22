# Shipping Rate Service Implementation Plan

A Rails service for fetching UPS shipping rates via the Shippo API, designed to be trivially extensible to additional carriers later.

## Overview

- **Integration approach:** HTTParty hitting Shippo REST API directly (no Shippo gem)
- **Carrier scope:** UPS only for now (client's UPS account connected to Shippo)
- **Origin address:** Hardcoded via Rails credentials/ENV
- **Product dimensions:** New `ProductDimension` model keyed by Square catalog object ID
- **Response shape:** Raw Shippo rate objects passed through to frontend

---

## Phase 1: Setup and Configuration

Add `httparty` to the Gemfile and bundle.

Set up Shippo credentials. Shippo uses a single API token (separate test and live tokens available from their dashboard). In `config/credentials.yml.enc`:

```yaml
shippo:
  api_token: shippo_test_xxx
shipping_origin:
  name: "Client Business Name"
  street1: "123 Warehouse Way"
  city: "Fort Collins"
  state: "CO"
  zip: "80521"
  country: "US"
  phone: "555-555-5555"
```

Use test credentials in development/test environments and live in production. Shippo's test mode returns realistic rate shapes without hitting real carriers.

---

## Phase 2: ProductDimension Model

Generate migration:

```ruby
create_table :product_dimensions do |t|
  t.string :square_catalog_object_id, null: false, index: { unique: true }
  t.decimal :length, precision: 8, scale: 2, null: false
  t.decimal :width, precision: 8, scale: 2, null: false
  t.decimal :height, precision: 8, scale: 2, null: false
  t.decimal :weight, precision: 8, scale: 2, null: false
  t.string :distance_unit, default: "in", null: false
  t.string :mass_unit, default: "lb", null: false
  t.timestamps
end
```

The `distance_unit` and `mass_unit` fields match Shippo's expected values (`in`/`cm`, `lb`/`oz`/`kg`/`g`) so they can pass through directly without translation.

**Model requirements:**
- Validate all dimension fields present and positive
- Validate `distance_unit` inclusion in `%w[in cm]`
- Validate `mass_unit` inclusion in `%w[lb oz kg g]`
- Add class method `ProductDimension.for_square_id(id)` for clean lookups

An admin UI for managing these records is out of scope for the shipping service itself — seed a few records manually for testing.

---

## Phase 3: Shippo HTTP Client

A thin wrapper in `app/services/shippo_client.rb` with a single responsibility: make authenticated requests to Shippo and return parsed responses.

```ruby
class ShippoClient
  include HTTParty
  base_uri "https://api.goshippo.com"

  class Error < StandardError; end
  class AuthError < Error; end
  class RateError < Error; end
  class TimeoutError < Error; end

  def initialize
    @headers = {
      "Authorization" => "ShippoToken #{Rails.application.credentials.dig(:shippo, :api_token)}",
      "Content-Type" => "application/json"
    }
  end

  def create_shipment(payload)
    response = self.class.post(
      "/shipments/",
      headers: @headers,
      body: payload.to_json,
      timeout: 10
    )
    handle_response(response)
  end

  private

  def handle_response(response)
    # - 2xx: return parsed body
    # - 401/403: raise AuthError
    # - 4xx: raise RateError with response details
    # - 5xx: raise Error
    # - Timeout: raise TimeoutError (rescue Net::ReadTimeout, etc.)
  end
end
```

**Notes:**
- 10-second timeout: Shippo occasionally takes 3-4s when multiple carriers are slow, but requests should not hang
- Keep this client dumb — no business logic, no filtering, no transformation

---

## Phase 4: Rate Service (Orchestrator)

`app/services/shipping_rate_service.rb` contains the business logic.

**Responsibilities:**
1. Look up dimensions for each line item
2. Build aggregate parcel (see parcel strategy below)
3. Build Shippo payload with origin + destination + parcel
4. Call ShippoClient
5. Filter rates to UPS only
6. Return raw Shippo rate objects

```ruby
class ShippingRateService
  class MissingDimensionsError < StandardError; end

  def initialize(destination:, line_items:)
    @destination = destination       # hash: street1, city, state, zip, country
    @line_items = line_items         # [{ square_catalog_object_id:, quantity: }, ...]
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
    filter_ups_rates(response["rates"])
  end

  private

  def origin_address
    Rails.application.credentials.shipping_origin.to_h
  end

  def build_parcel
    # Aggregate line items into a single parcel (see parcel strategy)
  end

  def filter_ups_rates(rates)
    rates.select { |r| r["provider"] == "UPS" }
  end
end
```

### Parcel Strategy (First Pass)

Treat the whole order as a single parcel:
- **Weight:** Sum `weight * quantity` across all line items
- **Dimensions:** Use the largest single item's L×W×H

This is a reasonable starting heuristic for industrial goods that don't nest. Bin-packing logic and multi-parcel shipments can come later once real order data shows the simple approach fails.

### UPS Filter

Shippo returns all rates across connected carriers. Filter with `rates.select { |r| r["provider"] == "UPS" }`. Keep this filter in one place so it's easy to remove when additional carriers are added.

### Error Handling

Missing dimensions should raise `MissingDimensionsError` with the offending Square catalog ID in the message. The controller translates this to a 422 with a useful message.

---

## Phase 5: Controller Endpoint

Thin controller action that delegates to the service.

**Route:** `POST /api/shipping/rates`

```ruby
def rates
  result = ShippingRateService.new(
    destination: rate_params[:destination].to_h,
    line_items: rate_params[:line_items].map(&:to_h)
  ).call
  render json: { rates: result }
rescue ShippingRateService::MissingDimensionsError => e
  render json: { error: e.message, code: "missing_dimensions" },
         status: :unprocessable_entity
rescue ShippoClient::Error => e
  render json: { error: "Unable to fetch rates", code: "shipping_service_unavailable" },
         status: :bad_gateway
end

private

def rate_params
  params.require(:shipping).permit(
    destination: [:street1, :street2, :city, :state, :zip, :country],
    line_items: [:square_catalog_object_id, :quantity]
  )
end
```

**Auth:** Apply whatever JWT/session middleware is already used on other Square-facing endpoints. This is called from the webapp during checkout.

---

## Phase 6: Testing

Three layers:

### ShippoClient Specs
- WebMock: verify correct headers, body shape, HTTP method
- Test error handling for each status code branch
- One or two VCR cassettes against real Shippo sandbox for drift detection

### ShippingRateService Specs
- Stub `ShippoClient#create_shipment` to return canned Shippo responses
- Test parcel-building logic (weight summing, dimension selection)
- Test UPS filter
- Test `MissingDimensionsError` path when a Square ID has no dimensions

### Controller Request Specs
- Param handling and validation
- Error mapping (422 for missing dimensions, 502 for Shippo failures)
- Response shape

---

## Phase 7: Manual Verification Checklist

Before handing off to the webapp:

1. Create a `ProductDimension` record for one of the client's actual SKUs
2. Hit the endpoint with a known destination address
3. Compare returned UPS rates to the client's UPS portal for the same shipment — should match within cents if the account is correctly linked in Shippo
4. Test a multi-item cart to verify parcel aggregation produces sensible rates
5. Test an invalid address (bad ZIP) and confirm clean error response (not a 500)

---

## Build Order Recommendation

1. **Phase 2** (migration + model) — no external dependencies, unblocks everything else
2. **Phase 3** (ShippoClient) — testable in isolation with real Shippo sandbox
3. **Phase 4** (ShippingRateService) — builds on client
4. **Phase 5** (controller) — thin wrapper, fast to add
5. **Phase 6** (tests) — can be written alongside each phase
6. **Phase 1** credentials setup happens before Phase 3

---

## Future Extensions (Out of Scope)

- Label purchase via `POST /transactions/` (using rate's `object_id`)
- Shippo tracking webhook endpoint for status updates back to customers/Square
- Multi-origin support (new `ShippingOrigin` model)
- Multi-carrier rate display (remove UPS filter, frontend handles provider display)
- Smarter parcel packing (bin-packing, multi-parcel shipments)
- Rate caching for common origin/destination/weight combinations