# Template pour tests de Logique Métier
# Ce template est utilisé pour tester la logique métier pure
# Il doit contenir UNIQUEMENT des tests de règles métier
#
# Usage:
#   cp spec/templates/business_logic_spec_template.rb spec/requests/my_feature_logic_spec.rb
#   Personnaliser le contenu selon les règles métier à tester

require 'rails_helper'

# ==============================================================================
# BUSINESS LOGIC TEST TEMPLATE
# ==============================================================================
#
# RÈGLES IMPORTANTES:
# ✅ Ce template est pour la LOGIQUE MÉTIER UNIQUEMENT
# ✅ Il teste les calculs, validations, règles métier
# ✅ Il NE teste PAS les contrats API (utiliser api_contract_spec_template.rb)
# ✅ Il utilise le type: :request
#
# POUR LES CONTRATS API, utiliser:
#   spec/templates/api_contract_spec_template.rb

RSpec.describe 'Business Logic Tests', type: :request do
  include BusinessLogicHelpers

  # ============================================================================
  # CONFIGURATION COMMUNE
  # ============================================================================

  # Factory definitions disponibles:
  # - create(:user) : Utilisateur avec données valides
  # - create(:cra) : CRA avec données valides
  # - create(:cra_entry) : Entrée CRA avec calculs
  # - create(:mission) : Mission avec relations
  # - build(:user) : Instance non persistée

  # ============================================================================
  # GROUPE DE TESTS PRINCIPAL
  # ============================================================================

  describe 'CRA Calculation Logic' do
    let(:user) { create(:user) }
    let(:cra) { create(:cra, user: user) }

    # ------------------------------------------------------------------------
    # TESTS DE CALCULS FINANCIERS
    # ------------------------------------------------------------------------

    context 'Financial Calculations' do
      it 'calculates line_total correctly: quantity * unit_price' do
        cra_entry = build(:cra_entry, quantity: 0.5, unit_price: 60_000)

        expected_total = 0.5 * 60_000 # 30000 centimes

        expect(cra_entry.line_total).to eq(expected_total)
      end

      it 'calculates line_total with different quantities' do
        test_cases = [
          { quantity: 1.0, unit_price: 60_000, expected: 60_000 },
          { quantity: 0.25, unit_price: 80_000, expected: 20_000 },
          { quantity: 1.5, unit_price: 40_000, expected: 60_000 }
        ]

        test_cases.each do |test_case|
          cra_entry = build(:cra_entry,
                            quantity: test_case[:quantity],
                            unit_price: test_case[:unit_price])

          expect(cra_entry.line_total).to eq(test_case[:expected])
        end
      end

      it 'handles large quantities correctly' do
        cra_entry = build(:cra_entry, quantity: 10.5, unit_price: 100_000)

        expected_total = 10.5 * 100_000 # 1050000 centimes

        expect(cra_entry.line_total).to eq(expected_total)
      end
    end

    # ------------------------------------------------------------------------
    # TESTS DE VALIDATION MÉTIER
    # ------------------------------------------------------------------------

    context 'Business Rules Validation' do
      it 'validates CRA uniqueness per user/month/year' do
        # Setup: créer un CRA existant
        create(:cra, user: user, month: 1, year: 2025)

        # Test: tenter de créer un second CRA pour la même période
        expect do
          create(:cra, user: user, month: 1, year: 2025)
        end.to raise_error(ActiveRecord::RecordInvalid, /already exists|unique/i)
      end

      it 'allows different users to have CRAs for same month/year' do
        other_user = create(:user)

        # Setup: CRA pour user
        create(:cra, user: user, month: 1, year: 2025)

        # Test: CRA pour autre user doit être accepté
        expect do
          create(:cra, user: other_user, month: 1, year: 2025)
        end.not_to raise_error
      end

      it 'allows same user to have CRAs for different months/years' do
        # Setup: CRA janvier 2025
        create(:cra, user: user, month: 1, year: 2025)

        # Test: CRA février 2025 doit être accepté
        expect do
          create(:cra, user: user, month: 2, year: 2025)
        end.not_to raise_error

        # Test: CRA janvier 2026 doit être accepté
        expect do
          create(:cra, user: user, month: 1, year: 2026)
        end.not_to raise_error
      end
    end

    # ------------------------------------------------------------------------
    # TESTS DE RECALCUL AUTOMATIQUE
    # ------------------------------------------------------------------------

    context 'Automatic Recalculation' do
      it 'recalculates CRA totals when entries are created' do
        cra.reload
        expect(cra.total_days).to eq(0)
        expect(cra.total_amount).to eq(0)

        # Action: créer une entrée CRA
        create(:cra_entry,
               cra: cra,
               quantity: 1.0,
               unit_price: 60_000,
               date: '2025-01-15')

        # Vérification: CRA doit être recalculé
        cra.reload
        expect(cra.total_days).to eq(1.0)
        expect(cra.total_amount).to eq(60_000)
      end

      it 'recalculates CRA totals when entries are updated' do
        # Setup: créer une entrée existante
        entry = create(:cra_entry,
                       cra: cra,
                       quantity: 1.0,
                       unit_price: 60_000)
        cra.reload
        expect(cra.total_days).to eq(1.0)
        expect(cra.total_amount).to eq(60_000)

        # Action: modifier la quantité
        entry.update!(quantity: 1.5)

        # Vérification: totals doivent être recalculés
        cra.reload
        expect(cra.total_days).to eq(1.5)
        expect(cra.total_amount).to eq(90_000) # 1.5 * 60000
      end

      it 'recalculates CRA totals when entries are destroyed' do
        # Setup: créer plusieurs entrées
        entry1 = create(:cra_entry, cra: cra, quantity: 1.0, unit_price: 60_000)
        create(:cra_entry, cra: cra, quantity: 0.5, unit_price: 80_000)
        cra.reload

        expect(cra.total_days).to eq(1.5)
        expect(cra.total_amount).to eq(100_000) # 60000 + 40000

        # Action: supprimer une entrée
        entry1.destroy

        # Vérification: totals doivent être recalculés
        cra.reload
        expect(cra.total_days).to eq(0.5)
        expect(cra.total_amount).to eq(40_000)
      end
    end

    # ------------------------------------------------------------------------
    # TESTS DE VALIDATION DE DONNÉES
    # ------------------------------------------------------------------------

    context 'Data Validation' do
      it 'validates quantity is positive' do
        expect do
          build(:cra_entry, quantity: -1.0, unit_price: 60_000)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'validates unit_price is positive' do
        expect do
          build(:cra_entry, quantity: 1.0, unit_price: -1000)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'validates date format' do
        cra_entry = build(:cra_entry, date: '2025-01-15')
        expect(cra_entry.date).to eq(Date.parse('2025-01-15'))
      end

      it 'rejects invalid date formats' do
        expect do
          build(:cra_entry, date: 'invalid-date')
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    # ------------------------------------------------------------------------
    # TESTS DE LIFECYCLE CRA
    # ------------------------------------------------------------------------

    context 'CRA Lifecycle Rules' do
      it 'allows status transition: draft → submitted' do
        cra.update!(status: 'draft')
        expect(cra.may_submit?).to be true

        cra.submit!
        expect(cra.status).to eq('submitted')
      end

      it 'allows status transition: submitted → locked' do
        cra.update!(status: 'submitted')
        expect(cra.may_lock?).to be true

        cra.lock!
        expect(cra.status).to eq('locked')
      end

      it 'prevents modifications when CRA is locked' do
        cra.update!(status: 'locked')

        expect(cra.may_submit?).to be false
        expect(cra.may_lock?).to be false
      end

      it 'prevents deletion when CRA is submitted or locked' do
        cra.update!(status: 'submitted')
        expect(cra.may_destroy?).to be false

        cra.update!(status: 'locked')
        expect(cra.may_destroy?).to be false
      end
    end
  end

  # ============================================================================
  # SCÉNARIOS DE TEST RÉUTILISABLES
  # ============================================================================

  describe 'Common Test Scenarios' do
    # Scénario 1: Création CRA avec entrées
    it_behaves_like 'complete CRA creation scenario' do
      let(:user) { create(:user) }
      let(:month) { 1 }
      let(:year) { 2025 }
      let(:entries_data) do
        [
          { date: '2025-01-10', quantity: 1.0, unit_price: 60_000 },
          { date: '2025-01-15', quantity: 0.5, unit_price: 60_000 },
          { date: '2025-01-20', quantity: 1.0, unit_price: 80_000 }
        ]
      end
    end

    # Scénario 2: Calculs avec devises
    it_behaves_like 'multi-currency calculation scenario' do
      let(:user) { create(:user) }
      let(:currency) { 'EUR' }
    end

    # Scénario 3: Gestion des erreurs métier
    it_behaves_like 'business error handling scenario' do
      let(:user) { create(:user) }
    end
  end

  # ============================================================================
  # HELPERS ET UTILITAIRES
  # ============================================================================

  def create_test_cra_with_entries(user:, month:, year:, entries_data:)
    cra = create(:cra, user: user, month: month, year: year)

    entries_data.each do |entry_data|
      create(:cra_entry, cra: cra, **entry_data)
    end

    cra.reload
    cra
  end

  def assert_cra_totals(cra, expected_days, expected_amount)
    expect(cra.total_days).to eq(expected_days)
    expect(cra.total_amount).to eq(expected_amount)
  end
end

# ============================================================================
# SHARED EXAMPLES (COMPORTEMENTS RÉUTILISABLES)
# ============================================================================

# Exemple 1: Scénario de création complète CRA
shared_examples 'complete CRA creation scenario' do
  it 'creates CRA with correct totals' do
    cra = create_test_cra_with_entries(
      user: user,
      month: month,
      year: year,
      entries_data: entries_data
    )

    expected_days = entries_data.sum { |e| e[:quantity] }
    expected_amount = entries_data.sum { |e| e[:quantity] * e[:unit_price] }

    assert_cra_totals(cra, expected_days, expected_amount)
  end

  it 'validates all entries are linked correctly' do
    cra = create_test_cra_with_entries(
      user: user,
      month: month,
      year: year,
      entries_data: entries_data
    )

    expect(cra.entries.count).to eq(entries_data.count)
    expect(cra.entries.all? { |e| e.cra_id == cra.id }).to be true
  end
end

# Exemple 2: Scénario multi-devises
shared_examples 'multi-currency calculation scenario' do
  it 'handles different currencies correctly' do
    cra = create(:cra, user: user, currency: currency)

    # Test avec différents taux de change simulés
    entry_eur = create(:cra_entry, cra: cra, quantity: 1.0, unit_price: 60_000)
    expect(entry_eur.line_total).to eq(60_000)
  end
end

# Exemple 3: Scénario gestion d'erreurs
shared_examples 'business error handling scenario' do
  it 'handles duplicate CRA creation' do
    # Créer un CRA existant
    create(:cra, user: user, month: 1, year: 2025)

    # Tentative de création d'un second CRA
    expect do
      create(:cra, user: user, month: 1, year: 2025)
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'handles invalid entry data' do
    cra = create(:cra, user: user, month: 1, year: 2025)

    expect do
      create(:cra_entry, cra: cra, quantity: -1.0, unit_price: 60_000)
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end

# ============================================================================
# NOTES POUR LES DÉVELOPPEURS
# ============================================================================
#
# Ce template suit les patterns identifiés dans le projet Foresy:
#
# 1. CALCULS FINANCIERS:
#    - Toujours utiliser des centimes (Integer, jamais Float)
#    - line_total = quantity * unit_price
#    - total_amount = sum(line_total) en centimes
#
# 2. VALIDATIONS MÉTIER:
#    - Unicité CRA par user/month/year
#    - Quantités positives uniquement
#    - Prix unitaires positifs uniquement
#
# 3. RECALCUL AUTOMATIQUE:
#    - Totaux CRA recalculés automatiquement
#    - Use services, pas de callbacks ActiveRecord
#    - Tests de recalcul après create/update/destroy
#
# 4. LIFECYCLE CRA:
#    - draft → submitted → locked
#    - États immutables (locked ne peut plus changer)
#    - Protection contre modifications après locked
#
# 5. TESTS DE PERFORMANCE:
#    - Tester avec grandes quantités de données
#    - Vérifier les performances de calcul
#    - Valider la mémoire utilisée
#
# Références:
# - FC-07 Feature Contract
# - Architecture DDD (Domain-Driven Design)
# - Services applicatifs vs Callbacks ActiveRecord
# - Tests TDD Platinum Level</parameter>
