FactoryBot.define do
  factory :translation do
    sequence(:code) { |n| "T#{n}" }
    name { "Test Translation" }
    language { "en" }
    license_notes { "" }
    public_domain { false }

    trait :kjv do
      code { "KJV" }
      name { "King James Version" }
      language { "en" }
      public_domain { true }
      license_notes { "Public domain in the United States." }
    end

    trait :rv1909 do
      code { "RV1909" }
      name { "Reina-Valera 1909" }
      language { "es" }
      public_domain { true }
      license_notes { "Public domain." }
    end
  end
end
