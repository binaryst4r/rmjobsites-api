class EquipmentRentalRequest < ApplicationRecord
  belongs_to :user, optional: true

  validates :customer_first_name, presence: true
  validates :customer_last_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_phone, presence: true
  validates :equipment_type, presence: true
  validates :pickup_date, presence: true
  validates :return_date, presence: true
  validates :rental_agreement_accepted, inclusion: { in: [true, false] }

  validate :return_date_after_pickup_date
  validate :rental_agreement_must_be_accepted

  private

  def return_date_after_pickup_date
    return if pickup_date.blank? || return_date.blank?

    if return_date <= pickup_date
      errors.add(:return_date, "must be after pickup date")
    end
  end

  def rental_agreement_must_be_accepted
    unless rental_agreement_accepted == true
      errors.add(:rental_agreement_accepted, "must be accepted")
    end
  end
end
