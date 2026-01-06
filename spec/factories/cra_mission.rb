# frozen_string_literal: true

FactoryBot.define do
  factory :cra_mission do
    # Associations (required for valid CraMission links)
    association :cra, factory: :cra
    association :mission, factory: :mission

    # Timestamps
    created_at { Time.current }

    # Validations ensured by model:
    # - cra_id presence (via belongs_to)
    # - mission_id presence (via belongs_to)
    # - mission_id uniqueness within cra (handled by model validation)

    # Traits for different test scenarios
    trait :draft_cra do
      cra { association :cra, :draft }
    end

    trait :submitted_cra do
      cra { association :cra, :submitted }
    end

    trait :locked_cra do
      cra { association :cra, :locked }
    end

    trait :active_mission do
      mission { association :mission, :active }
    end

    trait :in_progress_mission do
      mission { association :mission, :in_progress }
    end

    trait :completed_mission do
      mission { association :mission, :completed }
    end

    # Combined traits for realistic business scenarios
    trait :draft_with_active_mission do
      draft_cra
      active_mission
    end

    trait :submitted_with_active_mission do
      submitted_cra
      active_mission
    end

    trait :locked_with_completed_mission do
      locked_cra
      completed_mission
    end

    # Trait for testing uniqueness constraints
    trait :same_mission_multiple_cras do
      mission { association :mission }
    end

    # Traits for different time periods (using cra traits)
    trait :current_month do
      cra { association :cra, :current_month }
    end

    trait :previous_month do
      cra { association :cra, :previous_month }
    end

    # Trait for testing soft delete scenarios (if needed)
    trait :soft_deleted_cra do
      cra { association :cra, :discarded }
    end

    trait :soft_deleted_mission do
      mission { association :mission, :discarded }
    end

    # Combined traits for error scenarios
    trait :invalid_cra do
      cra { association :cra, :draft }
      mission { association :mission, :completed }
    end

    # Factory for creating multiple links (testing complex scenarios)
    factory :cra_mission_with_multiple_links do
      transient do
        additional_missions_count { 2 }
      end

      after(:create) do |cra_mission, evaluator|
        # Create additional mission links for the same CRA
        evaluator.additional_missions_count.times do
          create(:cra_mission, cra: cra_mission.cra)
        end
      end
    end

    # Factory for testing uniqueness violations
    factory :cra_mission_duplicate do
      cra { association :cra }
      mission { association :mission }
    end

    # Factory for link with calculated CRA totals
    trait :cra_with_totals do
      cra { association :cra, :with_calculated_totals }
    end

    # Custom validation testing
    trait :violates_uniqueness do
      after(:build) do |cra_mission|
        # This would require the specific cra and mission IDs
        # to already exist in a link, handled in tests
      end
    end
  end
end
