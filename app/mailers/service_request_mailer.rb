class ServiceRequestMailer < ApplicationMailer
  default from: 'notifications@rmjobsites.com'

  def assignment_notification(assignment)
    @assignment = assignment
    @service_request = assignment.service_request
    @assigned_to_user = assignment.assigned_to_user
    @assigned_by_user = assignment.assigned_by_user

    mail(
      to: @assigned_to_user.email,
      subject: "New Service Request Assignment: #{@service_request.customer_name}"
    )
  end
end
