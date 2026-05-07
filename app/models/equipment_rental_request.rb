class EquipmentRentalRequest < ApplicationRecord
  belongs_to :user, optional: true

  EQUIPMENT_TYPES = %w[Laser Level\ \Pipe\ Laser Slope\ Laser Transit Theodolite GPS\ On-Site].freeze
  RENTAL_DURATION_UNITS = %w[day week month].freeze

  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_phone, presence: true
  validates :equipment_type, presence: true
  validates :rental_duration_unit, presence: true, inclusion: { in: RENTAL_DURATION_UNITS }
  validates :rental_duration_amount, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :rental_agreement_accepted, inclusion: { in: [true, false] }

  validate :rental_agreement_must_be_accepted

  private

  def rental_agreement_must_be_accepted
    unless rental_agreement_accepted == true
      errors.add(:rental_agreement_accepted, "must be accepted")
    end
  end
end
