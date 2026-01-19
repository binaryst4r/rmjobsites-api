FactoryBot.define do
  factory :service_request do
    association :user, factory: :user
    customer_name { Faker::Name.name }
    company { Faker::Company.name }
    service_requested { %w[Installation Maintenance Repair Consultation].sample }
    pickup_date { 7.days.from_now.to_date }
    return_date { 14.days.from_now.to_date }
    manufacturer { Faker::Company.name }
    model { "Model-#{Faker::Alphanumeric.alphanumeric(number: 6).upcase}" }
    serial_number { Faker::Alphanumeric.alphanumeric(number: 10).upcase }

    trait :with_past_dates do
      pickup_date { 7.days.ago }
      return_date { 1.day.ago }
    end
  end
end
