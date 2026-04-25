FactoryBot.define do
  factory :bitcoin_address do
    sequence(:address) { |n| "bc1qexampletestaddressforspecs#{n.to_s.rjust(8, '0')}" }
    active { false }
    notes { nil }

    trait :active do
      active { true }
    end

    trait :archived do
      active { false }
      archived_at { 1.day.ago }
    end
  end
end
