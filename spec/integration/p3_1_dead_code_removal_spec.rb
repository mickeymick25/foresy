# frozen_string_literal: true

# 🔴 P3.1 — Nettoyage Code Mort : suppression des fichiers morts dans app/lib
#
# This spec characterizes the fix for audit point L1
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# The following files in app/lib are dead code — no controller, model,
# service, initializer, or route references them:
#
# - pundit.rb (~20 lines, stub inutile)
# - shared_result_adapter.rb (~410 lines, référence Shared::Result inexistant)
# - shared_result_kill_switches.rb (~696 lines, outils de migration)
# - step3_reporting_system.rb (~1112 lines, reporting de migration)
# - domain_leakage_detector.rb (~489 lines, outil de debug CLI)
#
# Total: ~2700 lines of dead code.
#
# Invariant: None of these classes should be autoloadable after cleanup.

require 'rails_helper'

RSpec.describe 'P3.1 — Dead code removal from app/lib' do
  describe 'Pundit stub' do
    it 'is not autoloadable' do
      expect(defined?(Pundit)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/lib/pundit.rb')
      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'SharedResultAdapter' do
    it 'is not autoloadable' do
      expect(defined?(SharedResultAdapter)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/lib/shared_result_adapter.rb')
      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'SharedResultKillSwitches' do
    it 'is not autoloadable' do
      expect(defined?(SharedResultKillSwitches)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/lib/shared_result_kill_switches.rb')
      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'Step3ReportingSystem' do
    it 'is not autoloadable' do
      expect(defined?(Step3ReportingSystem)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/lib/step3_reporting_system.rb')
      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'DomainLeakageDetector' do
    it 'is not autoloadable' do
      expect(defined?(DomainLeakageDetector)).to be_nil
    end

    it 'does not have the file' do
      path = Rails.root.join('app/lib/domain_leakage_detector.rb')
      expect(File.exist?(path)).to be(false)
    end
  end
end
