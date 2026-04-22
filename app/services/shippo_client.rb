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
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    raise TimeoutError, "Shippo request timed out: #{e.message}"
  end

  private

  def handle_response(response)
    case response.code
    when 200..299
      response.parsed_response
    when 401, 403
      raise AuthError, "Shippo authentication failed (#{response.code}): #{response.body}"
    when 400..499
      raise RateError, "Shippo request failed (#{response.code}): #{response.body}"
    else
      raise Error, "Shippo server error (#{response.code}): #{response.body}"
    end
  end
end
