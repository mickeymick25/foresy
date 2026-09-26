# frozen_string_literal: true

# P7-D1 — System Specs API — scénario phare (UC-4 + UC-9)
#
# Contrat système (3e contrat — assessment P7 §6) :
#   Use Case → HTTP → Controller → Services → Models → Git Ledger → état final.
#
# Règles P7 (arbitrage CTO du 22/09/2026) :
# - aucun mock/stub des composants métier (CraServices, GitLedger, models réels) ;
# - Git Ledger RÉEL : GIT_LEDGER_REAL=true + overlay LEDGER_PATH (tmpdir, D-12) ;
# - l'échec est provoqué par l'infrastructure (LEDGER_PATH = fichier existant),
#   jamais par un stub du service ;
# - assertions d'état métier observable (DB + pivots + Ledger), pas d'implémentation.

require 'rails_helper'
require 'tmpdir'

RSpec.describe 'System API — CRA lifecycle avec Git Ledger réel', type: :request do
  # INV-D12-01 — activation explicite du ledger réel, uniquement pour cette famille
  around do |example|
    previous_real = ENV.fetch('GIT_LEDGER_REAL', nil)
    ENV['GIT_LEDGER_REAL'] = 'true'
    example.run
  ensure
    ENV['GIT_LEDGER_REAL'] = previous_real
  end

  before do
    RateLimitService.reset_storage!
  end

  after do
    FileUtils.rm_rf(ledger_dir)
    RateLimitService.reset_storage!
  end

  let(:ledger_dir) { Dir.mktmpdir('foresy_p7_ledger') }
  let(:password) { 'TestPassword123!' }
  let(:email) { "system_p7_#{SecureRandom.hex(6)}@foresy.local" }

  # Overlay LEDGER_PATH (tmpdir) — pattern D-12 éprouvé (W3-D2 / W3-D4).
  # Le nettoyage s'effectue pendant que la constante pointe encore sur le tmpdir.
  def with_ledger_path(path)
    sc = GitLedgerRepository.singleton_class
    sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
    sc.const_set(:LEDGER_PATH, path)
    yield
  ensure
    FileUtils.rm_rf(path) if File.directory?(path)
    sc = GitLedgerRepository.singleton_class
    sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
    sc.const_set(:LEDGER_PATH, ENV.fetch('GIT_LEDGER_PATH', '/app/cra-ledger'))
  end

  def ledger_commit_count
    GitLedgerRepository.info[:commit_count] || 0
  end

  def create_mission_via_api!(headers, name, daily_rate)
    post '/api/v1/missions',
         params: { name: name, description: "#{name} (P7 system)", mission_type: 'time_based',
                   status: 'won', start_date: Date.current.iso8601, daily_rate: daily_rate,
                   currency: 'EUR' }.to_json,
         headers: headers
    expect(response).to have_http_status(:created)
    Mission.find(JSON.parse(response.body)['id'])
  end

  def create_entry_via_api!(headers, cra_id, mission, unit_price)
    post "/api/v1/cras/#{cra_id}/entries",
         params: { date: Date.current.iso8601, quantity: 0.5, unit_price: unit_price,
                   description: "Work — #{mission.name}", mission_id: mission.id }.to_json,
         headers: headers
    expect(response).to have_http_status(:created)
    JSON.parse(response.body)
  end

  describe 'UC-4 — CRA lifecycle complet (composition maximale)' do
    it 'exécute le parcours complet et laisse un état métier cohérent (DB + pivots + Ledger)' do
      with_ledger_path(ledger_dir) do
        # --- Signup (HTTP réel)
        post '/api/v1/signup',
             params: { email: email, password: password, password_confirmation: password }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:created)
        user = User.find_by!(email: email)

        # --- Login (JWT réel)
        post '/api/v1/auth/login', params: { email: email, password: password }.to_json,
                                   headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:ok)
        headers = { 'Authorization' => "Bearer #{JSON.parse(response.body)['token']}",
                    'Content-Type' => 'application/json' }

        # --- Company onboarding atomique (UC-3 sur le chemin)
        siren = SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')
        post '/api/v1/companies',
             params: { company: { name: 'P7 System Corp', siren: siren, siret: "#{siren}00001",
                                  legal_form: 'EI', vat_regime: 'franchise' },
                       role: 'independent' }.to_json,
             headers: headers
        expect(response).to have_http_status(:created)
        independent_company = user.user_companies.joins(:company).find_by(role: 'independent')&.company
        expect(independent_company).to be_present

        # --- Missions x2 (pivots user_missions + mission_companies créés par le service)
        mission_a = create_mission_via_api!(headers, 'P7 Mission A', 60_000)
        mission_b = create_mission_via_api!(headers, 'P7 Mission B', 70_000)
        expect(user.user_missions.where(mission_id: [mission_a.id, mission_b.id]).count).to eq(2)
        expect(mission_a.mission_companies.where(role: 'independent').count).to eq(1)

        # --- CRA (draft)
        post '/api/v1/cras',
             params: { month: Date.current.month, year: Date.current.year, currency: 'EUR',
                       description: 'P7 system CRA', status: 'draft' }.to_json,
             headers: headers
        expect(response).to have_http_status(:created)
        cra_id = JSON.parse(response.body)['id']
        cra = Cra.find(cra_id)
        expect(cra.status).to eq('draft')
        expect(cra.total_days.to_f).to eq(0.0)

        # --- Entries x2 (0,5 j mission A + 0,5 j mission B)
        entry_a = create_entry_via_api!(headers, cra_id, mission_a, 60_000)
        entry_b = create_entry_via_api!(headers, cra_id, mission_b, 70_000)
        expect(CraEntry.find(entry_a['id']).reload.missions.map(&:id)).to contain_exactly(mission_a.id)
        expect(CraEntry.find(entry_b['id']).reload.missions.map(&:id)).to contain_exactly(mission_b.id)
        cra.reload
        expect(cra.cra_entries.active.count).to eq(2)
        expect(cra.total_days.to_f).to eq(1.0)
        expect(cra.total_amount.to_f).to eq(65_000.0)

        # --- Submit
        post "/api/v1/cras/#{cra_id}/submit", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['status']).to eq('submitted')
        cra.reload
        expect(cra.status).to eq('submitted')
        expect(cra.total_days.to_f).to eq(1.0)

        # --- Lock (Git Ledger RÉEL)
        post "/api/v1/cras/#{cra_id}/lock", headers: headers
        expect(response).to have_http_status(:ok)
        locked_body = JSON.parse(response.body)
        expect(locked_body['status']).to eq('locked')
        expect(locked_body['locked_at']).to be_present
        cra.reload
        expect(cra.status).to eq('locked')
        expect(cra.locked_at).to be_present

        # Ledger réel : exactement un commit pour ce CRA, message contractuel
        expect(GitLedgerRepository.commit_exists_for_cra?(cra_id)).to be(true)
        commit_info = GitLedgerRepository.find_commit_info(cra_id)
        expect(commit_info[:commit_hash]).to match(/\A[0-9a-f]{40}\z/)
        expect(commit_info[:message]).to include("CRA locked — cra:#{cra_id}")
        commits_after_first_lock = ledger_commit_count

        # --- Double lock → 409, zéro delta de commits
        post "/api/v1/cras/#{cra_id}/lock", headers: headers
        expect(response).to have_http_status(:conflict)
        expect(ledger_commit_count).to eq(commits_after_first_lock)

        # --- Protection entry → 409
        patch "/api/v1/cras/#{cra_id}/entries/#{entry_a['id']}",
              params: { quantity: 2.0 }.to_json,
              headers: headers
        expect(response).to have_http_status(:conflict)

        # --- GET final : état cohérent
        get "/api/v1/cras/#{cra_id}", headers: headers
        expect(response).to have_http_status(:ok)
        final = JSON.parse(response.body)
        expect(final['status']).to eq('locked')
        expect(final['entries'].size).to eq(2)
        expect(final['total_days'].to_f).to eq(1.0)
      end
    end
  end

  describe 'UC-9 — Git Ledger : atomicité complète (échec infrastructure → rollback)' do
    let(:system_user) { create(:user) }
    let(:token) { AuthenticationService.login(system_user, '127.0.0.1', 'P7 System Spec')[:token] }
    let(:submitted_cra) do
      create(:cra, :with_creator, creator: system_user, status: 'submitted',
                                  month: Date.current.month, year: Date.current.year)
    end
    let(:entry) do
      create(:cra_entry, cra: submitted_cra, quantity: 0.5, unit_price: 60_000,
                         date: Date.current)
    end

    before do
      entry
      token
    end

    it "provoque un rollback complet puis se rétablit une fois l'infrastructure réparée" do
      blocked_dir = Dir.mktmpdir('foresy_p7_blocked')
      blocked = File.join(blocked_dir, 'blocked')
      FileUtils.touch(blocked) # chemin existant en tant que FICHIER → mkdir_p échoue

      begin
        # --- Échec : le ledger ne peut pas s'initialiser (fichier à la place du répertoire)
        # Les assertions ledger lisent PENDANT que LEDGER_PATH pointe sur `blocked`.
        with_ledger_path(blocked) do
          post "/api/v1/cras/#{submitted_cra.id}/lock",
               headers: { 'Authorization' => "Bearer #{token}" }

          expect(response).to have_http_status(:internal_server_error)
          failure_body = JSON.parse(response.body)
          expect(failure_body['code']).to eq('INTERNAL_SERVER_ERROR')

          # Ledger : aucun repository créé sur le chemin bloqué
          expect(File.file?(blocked)).to be(true)
          expect(GitLedgerRepository.initialized?).to be(false)
        end

        # Rollback complet : le CRA reste submitted, l'entry est intacte
        submitted_cra.reload
        expect(submitted_cra.status).to eq('submitted')
        expect(submitted_cra.locked_at).to be_nil
        expect(submitted_cra.cra_entries.active.count).to eq(1)

        # --- Récupération : une fois l'infrastructure réparée, le lock réussit
        # L'assertion ledger lit PENDANT que LEDGER_PATH pointe sur `ledger_dir`.
        with_ledger_path(ledger_dir) do
          post "/api/v1/cras/#{submitted_cra.id}/lock",
               headers: { 'Authorization' => "Bearer #{token}" }

          expect(response).to have_http_status(:ok)
          expect(GitLedgerRepository.commit_exists_for_cra?(submitted_cra.id)).to be(true)
        end
        expect(submitted_cra.reload.status).to eq('locked')
        expect(submitted_cra.locked_at).to be_present
      ensure
        FileUtils.rm_rf(blocked_dir)
      end
    end
  end
end
