# frozen_string_literal: true

puts "Loading config/environment.rb for #{ENV['RAILS_ENV']}"
require 'bundler/setup'
begin
  # Load the Rails application.
  require_relative 'application'

  # Initialize the Rails application.
  Rails.application.initialize!
rescue => e
  puts "Initialization failed: #{e.message}"
  puts e.backtrace
  exit 1
end
