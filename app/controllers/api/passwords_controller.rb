class Api::PasswordsController < ApplicationController
  skip_before_action :authenticate_request

  # POST /api/auth/forgot_password
  def forgot
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email) if email.present?

    if user
      token = user.generate_token_for(:password_reset)
      UserMailer.password_reset(user, token).deliver_later
    end

    render json: { message: "If an account exists for that email, a reset link has been sent." }, status: :ok
  end

  # POST /api/auth/reset_password
  def reset
    user = User.find_by_token_for(:password_reset, params[:token].to_s)

    unless user
      render json: { errors: ["Reset link is invalid or has expired."] }, status: :unprocessable_entity
      return
    end

    if user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      jwt = JsonWebToken.encode(user_id: user.id)
      render json: {
        token: jwt,
        user: UserSerializer.new(user).as_json
      }, status: :ok
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
