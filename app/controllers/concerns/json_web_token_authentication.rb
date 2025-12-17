module JsonWebTokenAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
  end

  private

  def authenticate_request
    header = request.headers["Authorization"]

    unless header
      Rails.logger.debug "No Authorization header found"
      return
    end

    token = header.split(" ").last

    begin
      @decoded = JsonWebToken.decode(token)
      Rails.logger.debug "Decoded token: #{@decoded.inspect}"

      if @decoded
        @current_user = User.find(@decoded[:user_id])
        Rails.logger.debug "Current user set: #{@current_user.inspect}"
      else
        Rails.logger.debug "Token decode returned nil - likely expired or invalid"
        render json: { errors: "Unauthorized - Token expired or invalid" }, status: :unauthorized
        return
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug "User not found: #{e.message}"
      render json: { errors: "Unauthorized - User not found" }, status: :unauthorized
    rescue JWT::DecodeError => e
      Rails.logger.debug "JWT decode error: #{e.message}"
      render json: { errors: "Unauthorized - Invalid token" }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def authenticate_user!
    render json: { errors: "Unauthorized" }, status: :unauthorized unless current_user
  end
end
