FactoryBot.define do
  factory :membership do
    association :user
    association :group
    role { "member" }

    trait :owner do
      role { "owner" }
    end
  end
end
