# frozen_string_literal: true

FactoryBot.define do
  factory :cra_entry_mission do
    # Simple associations
    association :cra_entry, factory: :cra_entry
    association :mission, factory: :mission
  end
end
