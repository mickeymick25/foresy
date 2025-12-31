# frozen_string_literal: true

FactoryBot.define do
  factory :company do
    name { "Company #{SecureRandom.hex(4)}" }
    legal_form { %w[SARL SAS Auto-entrepreneur EURL SA].sample }
    address_line_1 { Faker::Address.street_address }
    address_line_2 { Faker::Address.secondary_address }
    city { Faker::Address.city }
    postal_code { Faker::Address.zip_code }
    country { 'FR' }
    tax_number { "FR#{Faker::Number.number(digits: 9)}" }
    currency { 'EUR' }

    # Ensure SIRET is unique (exactly 14 digits)
    sequence(:siret) { |n| (Faker::Number.number(digits: 12).to_i + n).to_s.rjust(14, '0').to_s }

    # Ensure SIREN is unique when present (exactly 9 digits)
    sequence(:siren) { |n| (Faker::Number.number(digits: 7).to_i + n).to_s.rjust(9, '0').to_s }
  end
end
