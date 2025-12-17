class ServiceRequest < ApplicationRecord
  belongs_to :user, optional: true

  validates :customer_name, presence: true
  validates :company, presence: true
  validates :service_requested, presence: true
  validates :pickup_date, presence: true
  validates :return_date, presence: true
  validates :manufacturer, presence: true
  validates :model, presence: true
  validates :serial_number, presence: true

  validate :return_date_after_pickup_date

  private

  def return_date_after_pickup_date
    return if pickup_date.blank? || return_date.blank?

    if return_date <= pickup_date
      errors.add(:return_date, "must be after pickup date")
    end
  end
end
