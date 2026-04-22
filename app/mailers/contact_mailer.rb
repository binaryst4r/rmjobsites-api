class ContactMailer < ApplicationMailer
  default from: 'notifications@rmjobsites.com'

  def contact_form_submission(name:, email:, phone:, message:)
    @name = name
    @email = email
    @phone = phone
    @message = message

    mail(
      to: 'Ryan@rmjobsites.com',
      reply_to: email,
      subject: "New Contact Form Submission from #{name}"
    )
  end
end
