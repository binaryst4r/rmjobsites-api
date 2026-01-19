class User < ApplicationRecord
  has_secure_password

  has_many :service_requests
  has_many :assigned_service_requests,
           class_name: 'ServiceRequestAssignment',
           foreign_key: 'assigned_to_user_id',
           dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
end
