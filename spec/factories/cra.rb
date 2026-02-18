# frozen_string_literal: true

FactoryBot.define do
  factory :cra do
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

    # BACKWARD COMPATIBILITY: Automatically create user_cra relation when created_by_user_id is set
    # This ensures existing tests that use created_by_user_id continue to work
    # while also using the new relation-driven approach
    after(:create) do |cra|
      if cra.created_by_user_id.present?
        # Check if user_cra relation already exists (from :with_creator trait)
        existing_creator = cra.user_cras.find_by(role: 'creator')

        unless existing_creator
          # Create user_cra relation based on created_by_user_id
          UserCra.find_or_create_by!(
            cra_id: cra.id,
            role: 'creator'
          ) do |uc|
            uc.user_id = cra.created_by_user_id
            uc.created_at = cra.created_at || Time.current
          end
        end
      end
    end

    # Timestamps
    created_at { Time.current }
    updated_at { Time.current }

    # DDD Relation-Driven: No direct user association
    # User-CRA relationship is handled via user_cras pivot table
    # Use trait :with_creator to automatically create the pivot record

    # Trait: Create CRA WITH creator via pivot table (DDD Relation-Driven)
    trait :with_creator do
      transient do
        creator { create(:user) }
      end

      after(:create) do |cra, evaluator|
        cra.update!(created_by_user_id: evaluator.creator.id)
        create(:user_cra, cra: cra, user: evaluator.creator, role: 'creator')
      end
    end

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

    # Factory for creating CRAs with entries AND creator
    factory :cra_with_entries_and_creator do
      transient do
        entries_count { 2 }
        creator { create(:user) }
      end

      after(:create) do |cra, evaluator|
        # Create creator relation via pivot table
        create(:user_cra, cra: cra, user: evaluator.creator, role: 'creator')

        # Create CRA entries and associate them to this CRA
        evaluator.entries_count.times do
          entry = create(:cra_entry)
          create(:cra_entry_cra, cra: cra, cra_entry: entry)
        end
      end
    end
  end
end
