# frozen_string_literal: true

FactoryBot.define do
  factory :user_company do
    association :user
    association :company
    role { %w[independent client].sample }
  end
end
