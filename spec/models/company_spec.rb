# frozen_string_literal: true

require 'rails_helper'

# RSpec tests for Company model — FC-08 v3.2.3 (§56 Model Specs)
#
# Tests cover:
# - Validations: name, SIREN (presence / format / uniqueness), SIRET (optional /
#   format / uniqueness when present), legal_form nullable, vat_regime storage,
#   country default FR, currency default EUR
# - Scopes: .active / .deleted (INV-19), absence of default_scope (INV-20)
# - Soft deletion: discard / undiscard / discarded? (INV-21)
# - Database constraints: siren NOT NULL + UNIQUE, siret UNIQUE with multiple NULLs
#
# @see docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]
#
RSpec.describe Company, type: :model do
  describe 'Validations' do
    describe 'name' do
      it 'is required' do
        company = build(:company, name: nil)
        expect(company).not_to be_valid
        expect(company.errors[:name]).to include("can't be blank")
      end
    end

    describe 'siren' do
      it 'is required' do
        company = build(:company, siren: nil)
        expect(company).not_to be_valid
        expect(company.errors[:siren]).to include("can't be blank")
      end

      it 'validates format (9 digits)' do
        expect(build(:company, siren: '123456789')).to be_valid
        expect(build(:company, siren: '12345678')).not_to be_valid
        expect(build(:company, siren: '1234567890')).not_to be_valid
        expect(build(:company, siren: '12345A789')).not_to be_valid
      end

      it 'is unique at model level' do
        create(:company, siren: '123456789')
        duplicate = build(:company, siren: '123456789')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:siren]).to include('has already been taken')
      end
    end

    describe 'siret' do
      it 'is optional' do
        expect(build(:company, siret: nil)).to be_valid
      end

      it 'validates format when present (14 digits)' do
        expect(build(:company, siret: '12345678900012')).to be_valid
        expect(build(:company, siret: '1234567890001')).not_to be_valid
        expect(build(:company, siret: '123456789000123')).not_to be_valid
        expect(build(:company, siret: '12345A78900012')).not_to be_valid
      end

      it 'is unique when present' do
        create(:company, siret: '12345678900012')
        duplicate = build(:company, siret: '12345678900012')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:siret]).to include('has already been taken')
      end
    end

    describe 'legal_form' do
      it 'is nullable' do
        expect(build(:company, legal_form: nil)).to be_valid
      end
    end

    describe 'vat_regime' do
      it 'stores contextual VAT regime information (INV-13)' do
        company = create(:company, vat_regime: 'reelle_simplifiee')
        expect(company.reload.vat_regime).to eq('reelle_simplifiee')
      end

      it 'is nullable' do
        expect(build(:company, vat_regime: nil)).to be_valid
      end
    end

    describe 'defaults' do
      it 'defaults country to FR' do
        expect(create(:company, country: nil).reload.country).to eq('FR')
      end

      it 'defaults currency to EUR' do
        expect(create(:company, currency: nil).reload.currency).to eq('EUR')
      end
    end
  end

  describe 'Scopes' do
    let(:active_company) { create(:company) }
    let(:deleted_company) { create(:company) }

    before { deleted_company.discard }

    describe '.active' do
      it 'returns only companies with deleted_at IS NULL' do
        expect(Company.active).to contain_exactly(active_company)
      end
    end

    describe '.deleted' do
      it 'returns only companies with deleted_at IS NOT NULL' do
        expect(Company.deleted).to contain_exactly(deleted_company)
      end
    end
  end

  describe 'Absence of default scope (INV-20)' do
    it 'has no default_scope' do
      expect(Company.default_scopes).to be_empty
    end

    it 'returns soft-deleted records without explicit scope' do
      company = create(:company)
      company.discard
      expect(Company.all).to include(company)
    end
  end

  describe 'Soft deletion (INV-21)' do
    let(:company) { create(:company) }

    describe '#discard' do
      it 'populates deleted_at' do
        expect { company.discard }.to change { company.reload.deleted_at }.from(nil).to(be_present)
      end

      it 'excludes the company from Company.active' do
        company.discard
        expect(Company.active).not_to include(company)
      end

      it 'keeps the record persisted' do
        company.discard
        expect(Company.exists?(company.id)).to be true
      end

      it 'is idempotent' do
        company.discard
        expect { company.discard }.not_to change { company.reload.deleted_at }
      end
    end

    describe '#undiscard' do
      it 'clears deleted_at' do
        company.discard
        expect { company.undiscard }.to change { company.reload.deleted_at }.from(be_present).to(nil)
      end
    end

    describe '#discarded?' do
      it 'returns true when soft deleted' do
        company.discard
        expect(company.reload).to be_discarded
      end

      it 'returns false when active' do
        expect(company).not_to be_discarded
      end
    end
  end

  describe 'Database Constraints' do
    describe 'UNIQUE(siren) at database level (INV-09)' do
      it 'rejects duplicate SIREN bypassing model validation' do
        create(:company, siren: '123456789')
        duplicate = build(:company, siren: '123456789', siret: '98765432100012')
        expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    describe 'siren NOT NULL at database level (INV-07)' do
      it 'rejects NULL SIREN bypassing model validation' do
        company = build(:company, siren: nil)
        expect { company.save(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end

    describe 'UNIQUE(siret) with multiple NULLs (INV-11, INV-12)' do
      it 'permits multiple NULL SIRET values' do
        expect do
          create(:company, siret: nil, siren: '123456789')
          create(:company, siret: nil, siren: '987654321')
        end.not_to raise_error
      end

      it 'rejects duplicate non-null SIRET bypassing model validation' do
        create(:company, siret: '12345678900012')
        duplicate = build(:company, siret: '12345678900012', siren: '987654321')
        expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end