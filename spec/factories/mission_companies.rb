# frozen_string_literal: true

FactoryBot.define do
  factory :mission_company do
    association :mission
    association :company
    role { %w[independent client].sample }
  end

  # Specific role traits for testing
  trait :independent do
    role { 'independent' }
  end

  trait :client do
    role { 'client' }
  end

  # Combined traits for realistic scenarios
  trait :independent_role do
    independent
  end

  trait :client_role do
    client
  end
end
