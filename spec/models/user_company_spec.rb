# frozen_string_literal: true

require 'rails_helper'

# RSpec tests for UserCompany model — FC-08 v3.2.3 (§56 Model Specs)
#
# Tests cover:
# - Validations: required user, required company, supported roles (independent/client),
#   PostgreSQL enum behavior
# - Uniqueness: (user_id, company_id, role) — INV-18, database authoritative (§45.5)
# - Multiple roles with same company (Scenario 5) and multiple companies (§11)
# - Soft deletion: discard / undiscard / discarded? (INV-21)
# - Scopes: .active / .deleted (INV-19), absence of default_scope (INV-20)
# - No implicit resurrection of soft-deleted relationships (§27)
#
# @see docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]
#
RSpec.describe UserCompany, type: :model do
  let(:user) { create(:user) }
  let(:company) { create(:company) }

  describe 'Associations' do
    it { is_expected.to belong_to(:user).required }
    it { is_expected.to belong_to(:company).required }
  end

  describe 'Validations' do
    describe 'user' do
      it 'is required' do
        user_company = build(:user_company, user: nil)
        expect(user_company).not_to be_valid
        expect(user_company.errors[:user]).to be_present
      end
    end

    describe 'company' do
      it 'is required' do
        user_company = build(:user_company, company: nil)
        expect(user_company).not_to be_valid
        expect(user_company.errors[:company]).to be_present
      end
    end

    describe 'role' do
      it 'is required' do
        user_company = build(:user_company, role: nil)
        expect(user_company).not_to be_valid
        expect(user_company.errors[:role]).to be_present
      end

      it 'supports independent role' do
        expect(build(:user_company, role: 'independent')).to be_valid
      end

      it 'supports client role' do
        expect(build(:user_company, role: 'client')).to be_valid
      end

      it 'rejects unsupported roles at assignment (§25, strict enum)' do
        expect { build(:user_company, role: 'invalid') }.to raise_error(ArgumentError, /not a valid role/)
      end
    end
  end

  describe 'PostgreSQL enum behavior (§24)' do
    it 'rejects unknown role values at database level' do
      expect do
        sql = 'INSERT INTO user_companies (user_id, company_id, role, created_at, updated_at) '
        sql += "VALUES (#{user.id}, '#{company.id}', 'invalid_role', NOW(), NOW())"
        UserCompany.connection.execute(sql)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'keeps role stored in the existing user_company_role_enum' do
      column = UserCompany.connection.columns(:user_companies).find { |c| c.name == 'role' }
      expect(column.sql_type).to eq('user_company_role_enum')
    end
  end

  describe 'Uniqueness (INV-18)' do
    it 'rejects an identical (user, company, role) relationship at model level' do
      create(:user_company, user: user, company: company, role: 'independent')
      duplicate = build(:user_company, user: user, company: company, role: 'independent')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it 'is enforced at database level (§45.5 — database authoritative)' do
      create(:user_company, user: user, company: company, role: 'independent')
      duplicate = build(:user_company, user: user, company: company, role: 'independent')
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'Multiple roles with same company (§10, Scenario 5)' do
    it 'permits independent and client roles for the same user and company' do
      expect do
        create(:user_company, user: user, company: company, role: 'independent')
        create(:user_company, user: user, company: company, role: 'client')
      end.not_to raise_error

      expect(UserCompany.for_user(user).for_company(company).count).to eq(2)
    end
  end

  describe 'Multiple companies (§11)' do
    it 'permits a user with relationships across several companies' do
      other_company = create(:company)
      expect do
        create(:user_company, user: user, company: company, role: 'independent')
        create(:user_company, user: user, company: other_company, role: 'client')
      end.not_to raise_error

      expect(UserCompany.for_user(user).count).to eq(2)
    end
  end

  describe 'Scopes' do
    let(:active_relationship) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:deleted_relationship) { create(:user_company, user: user, company: company, role: 'client') }

    before { deleted_relationship.discard }

    describe '.active' do
      it 'returns only relationships with deleted_at IS NULL' do
        expect(UserCompany.active).to contain_exactly(active_relationship)
      end
    end

    describe '.deleted' do
      it 'returns only relationships with deleted_at IS NOT NULL' do
        expect(UserCompany.deleted).to contain_exactly(deleted_relationship)
      end
    end
  end

  describe 'Absence of default scope (INV-20)' do
    it 'has no default_scope' do
      expect(UserCompany.default_scopes).to be_empty
    end

    it 'returns soft-deleted records without explicit scope' do
      relationship = create(:user_company, user: user, company: company, role: 'independent')
      relationship.discard
      expect(UserCompany.all).to include(relationship)
    end
  end

  describe 'Soft deletion (INV-21)' do
    let(:relationship) { create(:user_company, user: user, company: company, role: 'independent') }

    describe '#discard' do
      it 'populates deleted_at' do
        expect { relationship.discard }.to change { relationship.reload.deleted_at }.from(nil).to(be_present)
      end

      it 'keeps the record persisted for audit purposes (§27)' do
        relationship.discard
        expect(UserCompany.exists?(relationship.id)).to be true
      end

      it 'is idempotent' do
        relationship.discard
        expect { relationship.discard }.not_to(change { relationship.reload.deleted_at })
      end
    end

    describe '#undiscard' do
      it 'clears deleted_at' do
        relationship.discard
        expect { relationship.undiscard }.to change { relationship.reload.deleted_at }.from(be_present).to(nil)
      end
    end

    describe '#discarded?' do
      it 'returns true when soft deleted' do
        relationship.discard
        expect(relationship.reload).to be_discarded
      end

      it 'returns false when active' do
        expect(relationship).not_to be_discarded
      end
    end
  end

  describe 'No implicit resurrection (§27)' do
    it 'rejects creating an identical active relationship when a soft-deleted one exists' do
      relationship = create(:user_company, user: user, company: company, role: 'independent')
      relationship.discard

      attempt = build(:user_company, user: user, company: company, role: 'independent')
      expect { attempt.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
