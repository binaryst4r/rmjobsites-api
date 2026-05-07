class PhoneCallRequestMailer < ApplicationMailer
  default from: 'notifications@rmjobsites.com'

  def support_notification(customer_info:, line_items:, notes: '')
    @customer_info = customer_info
    @line_items = line_items
    @notes = notes

    customer_email = customer_info[:email] || customer_info['email']

    mail(
      to: 'support@rmjobsites.com',
      reply_to: customer_email,
      subject: "Phone call request from #{customer_email}"
    )
  end
end
