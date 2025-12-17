require 'square'

Rails.application.config.square = {
  access_token: ENV.fetch('SQUARE_ACCESS_TOKEN', nil),
  environment: ENV.fetch('SQUARE_ENVIRONMENT', 'sandbox'),
  location_id: ENV.fetch('SQUARE_LOCATION_ID', nil),
  application_id: ENV.fetch('SQUARE_APPLICATION_ID', nil)
}

# Initialize Square client globally
SQUARE_CLIENT = Square::Client.new(
  base_url: Rails.application.config.square[:environment] == 'production' ?
    'https://connect.squareup.com' :
    'https://connect.squareupsandbox.com',
  token: Rails.application.config.square[:access_token]
)

Rails.logger.info "Square SDK initialized in #{Rails.application.config.square[:environment]} mode"
