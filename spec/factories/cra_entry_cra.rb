# frozen_string_literal: true

FactoryBot.define do
  factory :cra_entry_cra do
    # Association to CRA (required)
    association :cra, factory: :cra

    # Association to CRAEntry (required)
    association :cra_entry, factory: :cra_entry

    # Timestamps
    created_at { Time.current }
    updated_at { Time.current }
  end
end
