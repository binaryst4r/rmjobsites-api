class ServiceRequestAssignment < ApplicationRecord
  belongs_to :service_request
  belongs_to :assigned_to_user, class_name: 'User'
  belongs_to :assigned_by_user, class_name: 'User'

  validates :service_request_id, uniqueness: true
  validate :assigned_to_must_be_admin

  after_create :send_assignment_notification

  private

  def assigned_to_must_be_admin
    if assigned_to_user && !assigned_to_user.admin?
      errors.add(:assigned_to_user, "must be an admin user")
    end
  end

  def send_assignment_notification
    ServiceRequestMailer.assignment_notification(self).deliver_later
  end
end
