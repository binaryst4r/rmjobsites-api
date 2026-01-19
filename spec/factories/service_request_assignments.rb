FactoryBot.define do
  factory :service_request_assignment do
    association :service_request
    assigned_to_user { create(:user, :admin) }
    assigned_by_user { create(:user, :admin) }
  end
end
