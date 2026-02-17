# frozen_string_literal: true

FactoryBot.define do
  factory :user_cra do
    user { create(:user) }
    cra { create(:cra) }
    role { 'contributor' }
  end
end
