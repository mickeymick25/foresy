# frozen_string_literal: true

require 'rails_helper'

# FC-08 Architecture Invariants — schema-level guarantees (INV-01, INV-02, INV-03, INV-04, INV-06)
#
# These invariants are architectural: they forbid business foreign keys on domain
# entities and make UserCompany the only relationship carrier. They are pinned at
# the schema/association level so that any regression fails the suite immediately,
# instead of being verified only by manual inspection (P1.2).
#
# INV-15 (no fictitious legal entity for simulation) has no dedicated test: no
# simulation capability exists in the codebase (verified 14/09/2026, grep app/) —
# the invariant is a forward-looking architectural guarantee for future Feature
# Contracts. Documented in docs/technical/testing/[DONE]_2026_09_14_fc08_coverage_report.md.
#
# @see docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3] (invariants, lines 1606-1694)
#
RSpec.describe 'FC-08 Architecture Invariants', type: :model do
  describe 'INV-01 — Company Has No User FK' do
    it 'has no user_id column' do
      expect(Company.column_names).not_to include('user_id')
    end

    it 'has no belongs_to :user association' do
      expect(Company.reflect_on_association(:user)).to be_nil
    end
  end

  describe 'INV-02 — User Has No Company FK' do
    it 'has no company_id column' do
      expect(User.column_names).not_to include('company_id')
    end

    it 'has no belongs_to :company association' do
      expect(User.reflect_on_association(:company)).to be_nil
    end
  end

  describe 'INV-06 — Role Is Contextual (INV-06)' do
    it 'stores role on UserCompany only' do
      expect(UserCompany.column_names).to include('role')
      expect(User.column_names).not_to include('role')
      expect(Company.column_names).not_to include('role')
    end
  end

  describe 'INV-03 — UserCompany Is the Relationship' do
    it 'binds user and company explicitly' do
      expect(UserCompany.reflect_on_association(:user)).to be_present
      expect(UserCompany.reflect_on_association(:company)).to be_present
    end
  end

  describe 'INV-04 — User Can Exist Without Company' do
    it 'persists a user with zero user_companies' do
      user = create(:user)
      expect(UserCompany.for_user(user).count).to eq(0)
    end
  end
end
