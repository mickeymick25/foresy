# frozen_string_literal: true

FactoryBot.define do
  factory :cra_entry do
    # Core business fields with realistic values
    date { Faker::Date.between(from: 1.year.ago, to: Date.current) }
    quantity { 1 }
    unit_price { 50_000 } # 500€ - realistic default

    # Optional description with realistic content
    description { Faker::Lorem.paragraph(sentence_count: 1) }

    # Soft delete timestamp (nil by default)
    deleted_at { nil }

    # Timestamps
    created_at { Time.current }
    updated_at { Time.current }

    # Auto-associate with CRA via CraEntryCra relation table (DDD pattern)
    after(:create) do |entry|
      # Associate with a CRA if one exists via CraEntryCra
      create(:cra_entry_cra, cra_entry: entry) if entry.cra_entry_cras.empty?
      # Auto-associate with mission for export compatibility
      mission = create(:mission) if entry.missions.empty?
      create(:cra_entry_mission, mission: mission, cra_entry: entry) if mission && entry.missions.empty?
    end

    # Callback to handle data validation and realistic values
    after(:build) do |cra_entry|
      # Ensure quantity is positive and within reasonable bounds
      cra_entry.quantity = 0.25 if cra_entry.quantity <= 0
      cra_entry.quantity = [cra_entry.quantity, 100.0].min # Max 100 days per entry

      # Ensure unit_price is positive and in cents
      cra_entry.unit_price = 50_000 if cra_entry.unit_price <= 0 # Default 500€

      # Ensure description length is within limits
      if cra_entry.description && cra_entry.description.length > 500
        cra_entry.description = cra_entry.description.truncate(500)
      end
    end

    # Traits for different date scenarios
    trait :today do
      date { Date.current }
    end

    trait :yesterday do
      date { Date.current - 1.day }
    end

    trait :this_month do
      date { Date.current.beginning_of_month + Faker::Number.between(from: 0, to: 27).days }
    end

    trait :last_month do
      date { (Date.current - 1.month).beginning_of_month + Faker::Number.between(from: 0, to: 27).days }
    end

    trait :next_month do
      date { (Date.current + 1.month).beginning_of_month + Faker::Number.between(from: 0, to: 27).days }
    end

    trait :future_date do
      date { Faker::Date.forward(days: 30) }
    end

    trait :past_date do
      date { Faker::Date.backward(days: 365) }
    end

    # Traits for different quantity scenarios (common business values)
    trait :half_day do
      quantity { 0.5 }
    end

    trait :full_day do
      quantity { 1.0 }
    end

    trait :two_days do
      quantity { 2.0 }
    end

    trait :quarter_day do
      quantity { 0.25 }
    end

    trait :three_quarters_day do
      quantity { 0.75 }
    end

    trait :large_quantity do
      quantity { Faker::Number.decimal(l_digits: 2, r_digits: 2).to_f }
    end

    trait :small_quantity do
      quantity { Faker::Number.decimal(l_digits: 1, r_digits: 3).to_f }
    end

    # Traits for different unit price scenarios (in cents)
    trait :low_rate do
      unit_price { 30_000 } # 300€
    end

    trait :medium_rate do
      unit_price { 60_000 } # 600€
    end

    trait :high_rate do
      unit_price { 90_000 } # 900€
    end

    trait :premium_rate do
      unit_price { 120_000 } # 1200€
    end

    trait :variable_rate do
      unit_price { Faker::Number.between(from: 25_000, to: 150_000) }
    end

    # Traits for description scenarios
    trait :with_description do
      description { Faker::Lorem.sentence(word_count: 10) }
    end

    trait :without_description do
      description { nil }
    end

    trait :short_description do
      description { 'Quick task' }
    end

    trait :long_description do
      description { Faker::Lorem.paragraph(sentence_count: 3) }
    end

    # Combined traits for realistic business scenarios
    trait :standard_entry do
      full_day
      medium_rate
      this_month
      with_description
    end

    trait :half_day_entry do
      half_day
      medium_rate
      this_month
      with_description
    end

    trait :premium_entry do
      full_day
      premium_rate
      this_month
      with_description
    end

    trait :quick_task do
      quarter_day
      low_rate
      today
      short_description
    end

    trait :complex_task do
      two_days
      high_rate
      last_month
      long_description
    end

    trait :future_entry do
      full_day
      medium_rate
      future_date
      with_description
    end

    # Traits for testing calculations
    trait :for_calculation_test do
      quantity { 1.5 }
      unit_price { 60_000 } # 1.5 * 60000 = 90000 cents
    end

    trait :simple_calculation do
      quantity { 1.0 }
      unit_price { 50_000 } # 1.0 * 50000 = 50000 cents
    end

    # Traits for edge case testing
    trait :minimum_values do
      date { Date.current }
      quantity { 0.01 }
      unit_price { 100 } # 1€
    end

    trait :maximum_values do
      date { Date.current }
      quantity { 99.99 }
      unit_price { 999_999 } # Very high rate
    end

    trait :leap_year_date do
      date { Date.new(2024, 2, 29) }
    end

    trait :end_of_month do
      date { Date.current.end_of_month }
    end

    # Traits for soft delete testing
    trait :deleted do
      deleted_at { Time.current }
    end

    trait :not_deleted do
      deleted_at { nil }
    end

    # Traits for association testing - creates associations automatically
    trait :with_cra_association do
      after(:create) do |cra_entry|
        # Create association with a CRA if one is provided
        cra = create(:cra) unless cra_entry.cras.any?
        create(:cra_entry_cra, cra: cra, cra_entry: cra_entry)
      end
    end

    trait :with_mission_association do
      after(:create) do |cra_entry|
        # Create association with a mission if one is provided
        mission = create(:mission) unless cra_entry.missions.any?
        create(:cra_entry_mission, mission: mission, cra_entry: cra_entry)
      end
    end

    # Combined trait that creates both CRA and Mission associations
    trait :fully_associated do
      with_cra_association
      with_mission_association
    end

    # Trait for testing missing mission associations - removes only mission links, keeps CRA association
    trait :without_missions do
      after(:create) do |entry|
        # Supprime seulement les missions associées à l'entrée
        entry.cra_entry_missions.destroy_all
        entry.missions.destroy_all
        entry.reload
      end
    end

    # Advanced combined traits for complex test scenarios
    trait :complex_business_case do
      date { Faker::Date.between(from: 6.months.ago, to: Date.current) }
      quantity { Faker::Number.decimal(l_digits: 1, r_digits: 2).to_f }
      unit_price { Faker::Number.between(from: 40_000, to: 100_000) }
      description { Faker::Lorem.paragraph(sentence_count: 2) }
      created_at { Faker::Time.between(from: 6.months.ago, to: Time.current) }
    end

    # Factory for entries that should trigger specific validation scenarios
    trait :validation_edge_case do
      quantity { 0.001 } # Very precise quantity
      unit_price { 1 }   # Minimum unit price
    end

    # Ensure uniqueness in test data by using sequences
    factory :cra_entry_with_unique_date do
      transient do
        sequence_number { 0 }
      end

      after(:build) do |cra_entry, evaluator|
        cra_entry.date = Date.current + evaluator.sequence_number.days
      end
    end
  end
end
