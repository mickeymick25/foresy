# frozen_string_literal: true

# P6.2 — Nettoyer CraEntry : pas de callbacks commentés, pas d'attr_writer TDD

require 'rails_helper'

RSpec.describe 'P6.2 — CraEntry cleanup' do
  describe 'no commented-out code' do
    it 'does not have commented callbacks (before_create/update/destroy)' do
      source = File.read(Rails.root.join('app/models/cra_entry.rb'))
      expect(source).not_to match(/#\s*before_create/)
      expect(source).not_to match(/#\s*before_update/)
      expect(source).not_to match(/#\s*before_destroy/)
    end

    it 'does not have commented validate_cra_lifecycle method' do
      source = File.read(Rails.root.join('app/models/cra_entry.rb'))
      expect(source).not_to match(/#\s*def validate_cra_lifecycle!/)
    end

    it 'does not have NE PLUS UTILISER comment block' do
      source = File.read(Rails.root.join('app/models/cra_entry.rb'))
      expect(source).not_to match(/NE PLUS UTILISER/)
    end
  end

  describe 'no transient attr_writer for TDD' do
    it 'does not have attr_writer :cra, :mission' do
      source = File.read(Rails.root.join('app/models/cra_entry.rb'))
      expect(source).not_to match(/attr_writer\s+:cra,\s+:mission/)
    end
  end
end
