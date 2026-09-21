# frozen_string_literal: true

require 'rails_helper'

# W3-D3 — Contrat de la taxonomie d'erreurs du domaine CRA (lib/cra_errors.rb)
#
# Chaque classe d'erreur est un élément de contrat : message par défaut, code,
# http_status, to_h. Les spécialisations (InvalidPayloadError.field,
# InvalidTransitionError avec/sans statuts) sont caractérisées telles quelles.
RSpec.describe CraErrors do
  describe 'contrats par classe' do
    it 'BaseError expose le message par défaut du domaine CRA' do
      error = CraErrors::BaseError.new

      expect(error.message).to eq('An error occurred with the CRA')
      expect(error.default_message).to eq('An error occurred with the CRA')
    end

    it 'ApplicationBusinessError expose son message par défaut' do
      error = CraErrors::ApplicationBusinessError.new

      expect(error.message).to eq('An error occurred with the business logic')
    end

    it 'CraLockedError : 409 + code cra_locked' do
      error = CraErrors::CraLockedError.new

      expect(error.message).to eq('CRA is locked and cannot be modified')
      expect(error.code).to eq(:cra_locked)
      expect(error.http_status).to eq(:conflict)
    end

    it 'CraSubmittedError : 409 + code cra_submitted' do
      error = CraErrors::CraSubmittedError.new

      expect(error.message).to eq('CRA is submitted and cannot be modified')
      expect(error.code).to eq(:cra_submitted)
      expect(error.http_status).to eq(:conflict)
    end

    it 'InvalidTransitionError détaille la transition quand les statuts sont fournis' do
      error = CraErrors::InvalidTransitionError.new('draft', 'submitted')

      expect(error.message).to eq("Invalid transition from 'draft' to 'submitted'")
      expect(error.code).to eq(:invalid_transition)
      expect(error.http_status).to eq(:unprocessable_entity)
    end

    it 'InvalidTransitionError retombe sur un message générique sans statuts' do
      error = CraErrors::InvalidTransitionError.new

      expect(error.message).to eq('Invalid status transition')
    end

    it 'InvalidPayloadError expose le champ fautif dans to_h' do
      error = CraErrors::InvalidPayloadError.new('CRA is required', field: :cra)

      expect(error.code).to eq(:invalid_payload)
      expect(error.http_status).to eq(:unprocessable_entity)
      expect(error.to_h).to include(error: 'invalid_payload_error', field: :cra)
    end

    it 'DuplicateEntryError : 409 + code duplicate_entry' do
      error = CraErrors::DuplicateEntryError.new

      expect(error.message).to eq('An entry already exists for this mission and date')
      expect(error.code).to eq(:duplicate_entry)
      expect(error.http_status).to eq(:conflict)
    end

    it 'CraNotFoundError : 404 + code not_found' do
      error = CraErrors::CraNotFoundError.new

      expect(error.message).to eq('CRA not found')
      expect(error.code).to eq(:not_found)
      expect(error.http_status).to eq(:not_found)
    end

    it 'EntryNotFoundError : 404 + code not_found' do
      error = CraErrors::EntryNotFoundError.new

      expect(error.message).to eq('CRA entry not found')
      expect(error.code).to eq(:not_found)
      expect(error.http_status).to eq(:not_found)
    end

    it 'UnauthorizedError : 403 + code unauthorized' do
      error = CraErrors::UnauthorizedError.new

      expect(error.message).to eq('User is not authorized to perform this action')
      expect(error.code).to eq(:unauthorized)
      expect(error.http_status).to eq(:forbidden)
    end

    it 'NoIndependentCompanyError : 403 + code no_independent_company' do
      error = CraErrors::NoIndependentCompanyError.new

      expect(error.message).to eq('User must have an independent company to perform this action')
      expect(error.code).to eq(:no_independent_company)
      expect(error.http_status).to eq(:forbidden)
    end

    it 'MissionNotFoundError : 404 + code mission_not_found' do
      error = CraErrors::MissionNotFoundError.new

      expect(error.message).to eq('Mission not found or not accessible')
      expect(error.code).to eq(:mission_not_found)
      expect(error.http_status).to eq(:not_found)
    end

    it 'MissionNotLinkedError : 422 + code mission_not_linked' do
      error = CraErrors::MissionNotLinkedError.new

      expect(error.message).to eq('Mission is not linked to this CRA')
      expect(error.code).to eq(:mission_not_linked)
      expect(error.http_status).to eq(:unprocessable_entity)
    end

    it 'DateOutOfPeriodError : 422 + code date_out_of_period' do
      error = CraErrors::DateOutOfPeriodError.new

      expect(error.message).to eq('Entry date is outside the CRA period')
      expect(error.code).to eq(:date_out_of_period)
      expect(error.http_status).to eq(:unprocessable_entity)
    end

    it 'to_h expose la taxonomie (error démodulisé + code + message)' do
      error = CraErrors::CraLockedError.new

      expect(error.to_h).to include(error: 'cra_locked_error', code: :cra_locked,
                                    message: 'CRA is locked and cannot be modified')
    end
  end
end
