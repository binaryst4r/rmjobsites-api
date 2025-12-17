class Api::ConfigController < ApplicationController
  skip_before_action :authenticate_request

  # GET /api/config/square
  def square
    render json: {
      application_id: Rails.application.config.square[:application_id],
      location_id: Rails.application.config.square[:location_id],
      environment: Rails.application.config.square[:environment]
    }
  end
end
