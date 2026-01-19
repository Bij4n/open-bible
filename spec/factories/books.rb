FactoryBot.define do
  factory :book do
    association :translation
    sequence(:osis_code) { |n| "Bk#{n}" }
    sequence(:position)  { |n| n }
    name_en { "Book" }
    name_es { "Libro" }
    testament { :new }

    trait :genesis do
      osis_code { "Gen" }
      name_en { "Genesis" }
      name_es { "Génesis" }
      position { 1 }
      testament { :old }
    end

    trait :john do
      osis_code { "John" }
      name_en { "John" }
      name_es { "Juan" }
      position { 43 }
      testament { :new }
    end
  end
end
