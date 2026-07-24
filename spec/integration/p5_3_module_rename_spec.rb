# frozen_string_literal: true

# P5.3 — Module Rails renommé de App à Foresy

require 'rails_helper'

RSpec.describe 'P5.3 — Module Rails is Foresy' do
  it 'config/application.rb defines module Foresy' do
    content = File.read(Rails.root.join('config/application.rb'))
    expect(content).to match(/^module Foresy$/)
    expect(content).not_to match(/^module App$/)
  end

  it 'application class is Foresy::Application' do
    expect(defined?(Foresy::Application)).to eq('constant')
  end

  it 'App module is not defined' do
    expect(defined?(App)).to be_nil
  end
end
