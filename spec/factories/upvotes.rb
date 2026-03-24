FactoryBot.define do
  factory :upvote do
    association :user
    association :note
  end
end
