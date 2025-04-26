FactoryBot.define do
  factory :session do
    association :user
    token { SecureRandom.hex(32) }
    expires_at { 24.hours.from_now }
    last_activity_at { Time.current }
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { Faker::Internet.user_agent }

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end 