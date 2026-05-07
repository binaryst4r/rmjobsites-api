class Api::ContactController < ApplicationController
  skip_before_action :authenticate_request, only: [:create]

  def create
    name = contact_params[:name]
    email = contact_params[:email]
    phone = contact_params[:phone]
    message = contact_params[:message]

    if name.blank? || email.blank? || phone.blank? || message.blank?
      render json: { error: "Name, email, phone, and message are required" }, status: :unprocessable_entity
      return
    end

    # Send email notification
    ContactMailer.contact_form_submission(
      name: name,
      email: email,
      phone: phone,
      message: message
    ).deliver_later

    render json: { success: true, message: "Thank you for your message. We'll be in touch soon!" }, status: :ok
  rescue StandardError => e
    Rails.logger.error("Contact form error: #{e.message}")
    render json: { error: "Failed to send message. Please try again." }, status: :internal_server_error
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :phone, :message)
  end
end
