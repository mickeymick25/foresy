# frozen_string_literal: true

require 'rails_helper'

# W3-D3 — Caractérisation de CraEntryServices::List (chemins manquants)
RSpec.describe CraEntryServices::List do
  it 'retourne bad_request :missing_cra quand le CRA est absent' do
    result = described_class.call(cra: nil, current_user: nil)

    expect(result).to be_failure
    expect(result.status).to eq(:bad_request)
    expect(result.error).to eq(:missing_cra)
    expect(result.message).to eq('CRA is required')
  end
end
