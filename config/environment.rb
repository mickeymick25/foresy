# frozen_string_literal: true

puts "Loading config/environment.rb for #{ENV.fetch('RAILS_ENV', nil)}"
require 'bundler/setup'
begin
  # Load the Rails application.
  require_relative 'application'

  # Initialize the Rails application.
  Rails.application.initialize!
rescue StandardError => e
  puts "Initialization failed: #{e.message}"
  puts e.backtrace
  exit 1
end
