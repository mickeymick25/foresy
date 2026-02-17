# frozen_string_literal: true

FactoryBot.define do
  factory :user_mission do
    user { create(:user) }
    mission { create(:mission) }
    role { 'contributor' }
  end
end
