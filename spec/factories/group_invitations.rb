FactoryBot.define do
  factory :group_invitation do
    association :group
    invited_by { group.owner }
    sequence(:email) { |n| "invitee#{n}@example.com" }
    # token + expires_at auto-assigned by the model's before_validation
    # callbacks; we don't need to set them in the factory.

    trait :accepted do
      accepted_at { 1.minute.ago }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
