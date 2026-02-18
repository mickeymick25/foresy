# frozen_string_literal: true

FactoryBot.define do
  factory :mission do
    description { Faker::Lorem.paragraph(sentence_count: 2) }
    mission_type { %w[time_based fixed_price].sample }
    status { 'lead' }
    start_date { Faker::Date.forward(days: 30) }
    currency { 'EUR' }

    # Ensure name is unique
    sequence(:name) { |n| "Mission #{n} - #{Faker::Company.industry}" }

    # DDD Relation-Driven: No direct user association
    # User-Mission relationship is handled via user_missions pivot table
    # Use trait :with_creator to automatically create the pivot record

    # Conditional financial fields based on mission_type
    after(:build) do |mission|
      if mission.mission_type == 'time_based'
        mission.daily_rate = Faker::Number.between(from: 300, to: 1200) * 100 # In cents
      elsif mission.mission_type == 'fixed_price'
        mission.fixed_price = Faker::Number.between(from: 5000, to: 50_000) * 100 # In cents
      end
    end

    # NOTE: Removed automatic user_mission creation
    # Relations are now created explicitly by services (MissionServices::Create)
    # This avoids conflicts with tests that manually create user_missions

    # Trait: Create mission WITH creator via pivot table (DDD Relation-Driven)
    trait :with_creator do
      transient do
        creator { create(:user) }
      end

      after(:create) do |mission, evaluator|
        mission.update!(created_by_user_id: evaluator.creator.id)
        create(:user_mission, mission: mission, user: evaluator.creator, role: 'creator')
      end
    end

    # Trait for time-based missions
    trait :time_based do
      mission_type { 'time_based' }
      daily_rate { Faker::Number.between(from: 400, to: 1000) * 100 }
      fixed_price { nil }
    end

    # Trait for fixed-price missions
    trait :fixed_price do
      mission_type { 'fixed_price' }
      fixed_price { Faker::Number.between(from: 8000, to: 80_000) * 100 }
      daily_rate { nil }
    end

    # Trait for missions with end dates
    trait :with_end_date do
      end_date { start_date + Faker::Number.between(from: 30, to: 365).days }
    end

    # Trait for open-ended missions (no end date)
    trait :open_ended do
      end_date { nil }
    end

    # Trait for different statuses (for lifecycle testing)
    trait :lead do
      status { 'lead' }
    end

    trait :pending do
      status { 'pending' }
    end

    trait :won do
      status { 'won' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :completed do
      status { 'completed' }
    end

    # Traits for soft delete scenarios (for testing)
    trait :discarded do
      # For soft delete testing - assumes Mission model implements acts_as_paranoid
      # This sets the deleted_at timestamp if the model supports soft delete
      deleted_at { Time.current }
    end

    trait :active do
      # For testing active (non-deleted) missions
      deleted_at { nil }
    end

    # Combined traits for realistic scenarios
    trait :time_based_active do
      time_based
      won
      with_end_date
      active
    end

    trait :fixed_price_completed do
      fixed_price
      completed
      with_end_date
      active
    end

    trait :open_ended_lead do
      time_based
      lead
      open_ended
      active
    end

    # Combined traits for soft delete testing scenarios
    trait :discarded_time_based do
      time_based
      discarded
    end

    trait :discarded_fixed_price do
      fixed_price
      discarded
    end
  end
end
