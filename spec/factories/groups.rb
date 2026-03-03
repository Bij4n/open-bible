FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Bible Study #{n}" }
    description { "A small gathering." }
    association :owner, factory: :user
    privacy { "invite_only" }

    trait :private_group do
      privacy { "private_group" }
    end

    trait :with_invitation_code do
      sequence(:invitation_code) { |n| "CODE#{n.to_s.rjust(4, '0')}" }
    end

    # Build an owner Membership row for the `owner` user automatically so
    # member? / membership queries behave naturally in specs.
    after(:create) do |group|
      Membership.find_or_create_by!(user: group.owner, group: group) do |m|
        m.role = :owner
      end
    end

    trait :with_members do
      transient do
        member_count { 2 }
      end

      after(:create) do |group, eval|
        create_list(:user, eval.member_count).each do |user|
          create(:membership, user: user, group: group, role: :member)
        end
      end
    end
  end
end
