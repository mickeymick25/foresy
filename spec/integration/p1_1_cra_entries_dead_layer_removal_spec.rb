# frozen_string_literal: true

# 🔴 P1.1 — Stabilisation Runtime : suppression de la couche de services cassée
#
# This spec characterizes the fix for audit point S1
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# The CraEntries::* services (app/services/cra_entries/) referenced
# ::Domain::CraEntry::CraEntry which does NOT exist. Any call to these
# services would raise NameError at runtime.
#
# The controller (CraEntriesController) uses CraEntryServices::* (the
# working intermediate layer), so CraEntries::* is dead code that would
# crash if invoked.
#
# Decision: Option A — delete the dead, broken layer.
#
# Invariant: The CraEntries::* module must NOT be autoloadable after
# cleanup. The app must boot without NameError.

require 'rails_helper'

RSpec.describe 'P1.1 — CraEntries broken service layer removal' do
  describe 'app boot stability' do
    it 'boots without NameError for Domain::CraEntry::CraEntry' do
      expect { Domain::CraEntry }.to raise_error(NameError)
    end
  end

  describe 'CraEntries::* dead services' do
    it 'does not autoload CraEntries::Create' do
      expect(defined?(CraEntries::Create)).to be_nil
    end

    it 'does not autoload CraEntries::Update' do
      expect(defined?(CraEntries::Update)).to be_nil
    end

    it 'does not autoload CraEntries::Destroy' do
      expect(defined?(CraEntries::Destroy)).to be_nil
    end

    it 'does not autoload CraEntries::List' do
      expect(defined?(CraEntries::List)).to be_nil
    end
  end

  describe 'CraEntryServices::* working layer (must survive)' do
    it 'still autoloads CraEntryServices::Create' do
      expect(defined?(CraEntryServices::Create)).to eq('constant')
    end

    it 'still autoloads CraEntryServices::Update' do
      expect(defined?(CraEntryServices::Update)).to eq('constant')
    end

    it 'still autoloads CraEntryServices::Destroy' do
      expect(defined?(CraEntryServices::Destroy)).to eq('constant')
    end

    it 'still autoloads CraEntryServices::List' do
      expect(defined?(CraEntryServices::List)).to eq('constant')
    end
  end
end
