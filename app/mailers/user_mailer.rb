class UserMailer < ApplicationMailer
  default from: 'notifications@rmjobsites.com'

  def password_reset(user, token)
    @user = user
    @reset_url = "#{frontend_url}/reset-password/#{token}"

    mail(to: @user.email, subject: "Reset your RMJobsites password")
  end

  private

  def frontend_url
    return ENV["FRONTEND_URL"] if ENV["FRONTEND_URL"].present?

    Rails.env.production? ? "https://rmjobsites.com" : "http://localhost:5173"
  end
end
