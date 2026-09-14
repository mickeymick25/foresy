# frozen_string_literal: true

FactoryBot.define do
  factory :user_company do
    user { create(:user) }
    company { create(:company) }
    role { 'independent' }

    trait :independent do
      role { 'independent' }
    end

    trait :client do
      role { 'client' }
    end
  end
end