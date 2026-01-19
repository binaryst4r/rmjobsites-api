require 'sendgrid-ruby'

Rails.application.config.sendgrid = {
  api_key: ENV.fetch('SENDGRID_API_KEY', nil),
  from_email: ENV.fetch('SENDGRID_FROM_EMAIL', 'orders@rmjobsites.com'),
  from_name: ENV.fetch('SENDGRID_FROM_NAME', 'RM Jobsites')
}

if Rails.application.config.sendgrid[:api_key].present?
  Rails.logger.info "SendGrid initialized with from: #{Rails.application.config.sendgrid[:from_email]}"
else
  Rails.logger.warn "SendGrid API key not configured - email sending will be disabled"
end
