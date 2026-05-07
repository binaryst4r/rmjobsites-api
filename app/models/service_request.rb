class ServiceRequest < ApplicationRecord
  belongs_to :user, optional: true
  has_one :assignment, class_name: 'ServiceRequestAssignment', dependent: :destroy

  SERVICE_TYPES = [
    'Level',
    'Laser',
    'Pipe Laser',
    'Slope Laser',
    'Transit',
    'Theodolite',
    'GPS On-Site Service',
    'GPS 3D Modeling',
    'Chase Drain',
    'Unsure - please call me'
  ].freeze

  TRINARY_STATUS = %w[NO YES DONT_KNOW].freeze
  RENTAL_STATUS = %w[NO YES].freeze

  validates :customer_name, presence: true
  validates :customer_email, presence: true
  validates :customer_phone, presence: true
  validates :company, presence: true
  validates :service_requested, presence: true, inclusion: { in: SERVICE_TYPES }
  validates :damage_status, inclusion: { in: TRINARY_STATUS }, allow_nil: true
  validates :replacement_status, inclusion: { in: TRINARY_STATUS }, allow_nil: true
  validates :rental_status, inclusion: { in: RENTAL_STATUS }, allow_nil: true

  # Drop-off date is required for everything except the "Unsure - please call me" path,
  # where the customer hasn't decided what they're bringing yet.
  validates :pickup_date, presence: true, unless: :unsure_service?

  def unsure_service?
    service_requested == 'Unsure - please call me'
  end

  def gps_or_chase_drain?
    ['GPS On-Site Service', 'GPS 3D Modeling', 'Chase Drain'].include?(service_requested.to_s)
  end
end
