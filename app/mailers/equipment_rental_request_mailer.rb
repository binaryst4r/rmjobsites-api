class EquipmentRentalRequestMailer < ApplicationMailer
  default from: 'notifications@rmjobsites.com'

  def customer_confirmation(rental_request)
    @rental_request = rental_request

    mail(
      to: rental_request.customer_email,
      cc: 'support@rmjobsites.com',
      subject: 'We received your rental request'
    )
  end
end
