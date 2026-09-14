# frozen_string_literal: true

# FC-08 v3.2.3 — Company & User-Company Relationships (contract §§47-50)
#
# Sequential migration plan:
# - SIREN: nullable + non-unique index → NOT NULL + UNIQUE (index replaced, not duplicated)
# - SIRET: NOT NULL → nullable (existing unique index retained; PostgreSQL allows multiple NULLs)
# - vat_regime: add nullable string column (no enum, no calculation logic)
# - user_companies.deleted_at: add nullable datetime column (soft deletion, INV-21)
#
# The PostgreSQL enum user_company_role_enum already contains the FC-08 supported
# roles (independent, client) and is retained unchanged (§51).
#
# Per §47.1, existing data is verified before changing nullability: the migration
# refuses to proceed if companies without SIREN exist.
class Fc08CompanyUserCompanyContract < ActiveRecord::Migration[8.1]
  def up
    verify_existing_data

    # SIREN — replace non-unique index, enforce NOT NULL, add unique index
    remove_index :companies, name: 'index_companies_on_siren' if index_exists?(:companies, :siren, name: 'index_companies_on_siren')
    change_column_null :companies, :siren, false
    add_index :companies, :siren, unique: true, name: 'index_companies_on_siren'

    # SIRET — make nullable, keep existing unique index
    change_column_null :companies, :siret, true

    # vat_regime — contextual string, nullable (§49)
    add_column :companies, :vat_regime, :string

    # UserCompany soft deletion (§50, INV-21)
    add_column :user_companies, :deleted_at, :datetime
  end

  def down
    remove_column :user_companies, :deleted_at
    remove_column :companies, :vat_regime
    change_column_null :companies, :siret, false
    remove_index :companies, name: 'index_companies_on_siren' if index_exists?(:companies, :siren, name: 'index_companies_on_siren')
    change_column_null :companies, :siren, true
    add_index :companies, :siren, name: 'index_companies_on_siren'
  end

  private

  # §47.1 — existing data must be verified before changing nullability or uniqueness
  def verify_existing_data
    null_siren_count = select_value('SELECT COUNT(*) FROM companies WHERE siren IS NULL').to_i
    return if null_siren_count.zero?

    raise ActiveRecord::MigrationError,
          "FC-08: #{null_siren_count} company(ies) without SIREN — populate siren for all companies before migrating (contract §47.1)"
  end
end
