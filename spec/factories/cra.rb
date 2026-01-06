# frozen_string_literal: true

FactoryBot.define do
  factory :cra do
    # Association with user (creator)
    association :user, factory: :user

    # Core business fields with realistic values
    sequence(:month) { |n| ((n - 1) % 12) + 1 } # Cycles through 1-12
    sequence(:year) { |n| 2024 + ((n - 1) / 12).to_i } # Generates years starting from 2024

    status { 'draft' }
    currency { 'EUR' }
    description { Faker::Lorem.paragraph(sentence_count: 2) }
    total_days { nil }
    total_amount { nil }
    locked_at { nil }

    # Callback to handle calculated fields
    after(:build) do |cra|
      cra.total_days = 0 if cra.total_days.nil?
      cra.total_amount = 0 if cra.total_amount.nil?
    end

    # Timestamps
    created_at { Time.current }
    updated_at { Time.current }

    # Traits for different CRA statuses (lifecycle testing)
    trait :draft do
      status { 'draft' }
      locked_at { nil }
    end

    trait :submitted do
      status { 'submitted' }
      locked_at { nil }
    end

    trait :locked do
      status { 'locked' }
      locked_at { Time.current }
    end

    # Trait for soft delete (discarded) - ADDED for CraMissionLinker tests
    trait :discarded do
      deleted_at { Time.current }
    end

    # Trait for active (not discarded)
    trait :active do
      deleted_at { nil }
    end

    # Traits for different time periods
    trait :current_month do
      month { Date.current.month }
      year { Date.current.year }
    end

    trait :previous_month do
      month { (Date.current - 1.month).month }
      year { (Date.current - 1.month).year }
    end

    # Trait for different currencies
    trait :eur_currency do
      currency { 'EUR' }
    end

    trait :usd_currency do
      currency { 'USD' }
    end

    # Combined traits for realistic scenarios
    trait :draft_current_month do
      draft
      current_month
      active
    end

    trait :submitted_current_month do
      submitted
      current_month
      active
    end

    trait :locked_current_month do
      locked
      current_month
      active
    end

    # Trait for CRAs with calculated totals
    trait :with_calculated_totals do
      total_days { Faker::Number.decimal(l_digits: 1, r_digits: 2) }
      total_amount { Faker::Number.between(from: 10_000, to: 1_000_000) } # In cents
    end

    # Factory for creating CRAs with associated entries for testing calculations
    factory :cra_with_entries do
      transient do
        entries_count { 2 }
      end

      after(:create) do |cra, evaluator|
        # Create CRA entries and associate them to this CRA
        evaluator.entries_count.times do
          entry = create(:cra_entry)
          create(:cra_entry_cra, cra: cra, cra_entry: entry)
        end
      end
    end
  end
end
