# frozen_string_literal: true

# 🔴 P3.2 — Nettoyage Code Mort : suppression des concerns modèles orphelins
#
# This spec characterizes the fix for audit point M1
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# The following model concerns exist but are NEVER included by any model:
#
# - domain_driven.rb (~145 lines)
# - soft_deletable.rb (~120 lines)
# - validatable.rb (~170 lines)
#
# Models implement the functionality manually (duplicating what these
# concerns would provide) instead of including them.
#
# Invariant: None of these concerns should be autoloadable after cleanup.

require 'rails_helper'

RSpec.describe 'P3.2 — Orphan model concerns removal' do
  describe 'DomainDriven concern' do
    it 'is not autoloadable' do
      expect(defined?(DomainDriven)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/models/concerns/domain_driven.rb')
      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'SoftDeletable concern' do
    it 'is not autoloadable' do
      expect(defined?(SoftDeletable)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/models/concerns/soft_deletable.rb')
      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'Validatable concern' do
    it 'is not autoloadable' do
      expect(defined?(Validatable)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/models/concerns/validatable.rb')
      expect(File.exist?(path)).to be(false)
    end
  end
end
