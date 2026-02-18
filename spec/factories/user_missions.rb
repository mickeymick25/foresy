# frozen_string_literal: true

FactoryBot.define do
  factory :user_mission do
    user { create(:user) }
    mission { create(:mission, :with_creator) }
    role { 'contributor' }

    trait :as_creator do
      role { 'creator' }
    end

    trait :as_contributor do
      role { 'contributor' }
    end

    trait :as_reviewer do
      role { 'reviewer' }
    end
  end
end
