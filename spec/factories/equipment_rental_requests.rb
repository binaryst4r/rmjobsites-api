FactoryBot.define do
  factory :equipment_rental_request do
    association :user, factory: :user
    customer_first_name { Faker::Name.first_name }
    customer_last_name { Faker::Name.last_name }
    customer_email { Faker::Internet.email }
    customer_phone { Faker::PhoneNumber.phone_number }
    equipment_type { %w[Excavator Bulldozer Crane Forklift Loader].sample }
    pickup_date { 7.days.from_now.to_date }
    return_date { 14.days.from_now.to_date }
    rental_agreement_accepted { true }

    trait :agreement_not_accepted do
      rental_agreement_accepted { false }
    end

    trait :with_invalid_dates do
      pickup_date { 14.days.from_now }
      return_date { 7.days.from_now }
    end
  end
end
