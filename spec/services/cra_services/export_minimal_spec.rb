# frozen_string_literal: true

# Minimal test to reproduce CraServices::Export :internal_error
# Created: 27 Jan 2026

require 'rails_helper'

RSpec.describe CraServices::Export, 'minimal reproduction' do
  let(:company) { create(:company) }
  let(:user) { create(:user) }

  before do
    # Create Independent relationship via UserCompany (pas de FK direct User -> Company)
    create(:user_company, user: user, company: company, role: 'independent')
  end

  let(:cra) do
    create(
      :cra,
      user: user,
      month: 1,
      year: 2024,
      status: 'submitted'
    )
  end

  it 'exports a submitted CRA with no entries' do
    result = described_class.call(cra: cra, current_user: user)

    expect(result).to be_success
    expect(result.data).to be_present
  end
end
