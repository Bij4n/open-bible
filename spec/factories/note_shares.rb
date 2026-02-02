FactoryBot.define do
  factory :note_share do
    association :note
    # shareable defaults to a User; use `:with_group` trait to share
    # with a Group instead.
    shareable { association(:user) }

    trait :with_group do
      shareable { association(:group) }
    end
  end
end
