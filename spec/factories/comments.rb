FactoryBot.define do
  factory :comment do
    association :note
    association :user
    body { "A comment." }
    parent { nil }

    trait :reply do
      association :parent, factory: :comment
    end
  end
end
