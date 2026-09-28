# frozen_string_literal: true

# Contrat #14 concurrentiel (BACKLOG #26 — arbitrage CTO 26/09, R-1) :
# l'invariant FC-07 « un seul CRA par (créateur, mois, année) » doit tenir SOUS CONCURRENCE.
#
# Protocole (transformé du runner d'investigation #26, barrière déterministe) : deux clients
# traversent chacun une pré-vérification (fenêtre TOCTOU côté client — double-clic/retry),
# puis appellent le service concurremment. Le service doit absorber l'interleaving :
# exactement 1 CRA persisté + 1 success + 1 conflict :cra_already_exists (409).
#
# RED attendu avant R-1 : 2 success, 2 CRAs persistés (race démontrée au §3 de
# docs/technical/audits/2026_09_26_26_race14_concurrency_investigation.md).
# GREEN attendu après R-1 : le lock transactionnel sérialise (lock → check → insert).
require 'rails_helper'

RSpec.describe 'CraServices::Create — contrat #14 concurrentiel (R-1)' do
  # Concurrence réelle : une connexion par thread — pas de transaction d'exemple.
  self.use_transactional_tests = false

  let(:suffix) { SecureRandom.hex(3) }
  let(:user) do
    User.create!(email: "race14-#{suffix}@example.com", password: 'password123',
                 name: "Race14-#{suffix}", active: true)
  end
  let(:company) { Company.create!(name: "Race14-#{suffix}", siren: '999269999', currency: 'EUR') }
  let(:cra_params) { { month: 1, year: 2030, currency: 'EUR' } }

  before do
    Company.where(siren: '999269999').where.not(id: company.id).destroy_all
    UserCompany.create!(user: user, company: company, role: 'independent')
  end

  after do
    Cra.joins(:user_cras).where(user_cras: { user_id: user.id }).destroy_all
    UserCompany.where(user_id: user.id).destroy_all
    company.destroy!
    user.destroy!
    Company.where(siren: '999269999').destroy_all
  rescue StandardError
    nil
  end

  it 'sérialise les créations concurrentes : 1 success + 1 conflict 409, exactement 1 CRA' do
    mutex = Mutex.new
    condition = ConditionVariable.new
    ready = 0
    client_guards = []
    outcomes = []

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          # Pré-vérification côté client (même requête que la garde du service) :
          # les deux clients traversent la fenêtre TOCTOU avant l'appel.
          existing = Cra.joins(:user_cras)
                        .where(user_cras: { user_id: user.id, role: 'creator' })
                        .where(month: 1, year: 2030, deleted_at: nil).exists?

          mutex.synchronize do
            client_guards << existing
            ready += 1
            condition.signal
          end
          mutex.synchronize { condition.wait(mutex) while ready < 2 }

          outcomes << CraServices::Create.call(cra_params: cra_params, current_user: user)
        end
      end
    end
    threads.each(&:join)

    persisted = Cra.joins(:user_cras)
                   .where(user_cras: { user_id: user.id, role: 'creator' },
                          month: 1, year: 2030, deleted_at: nil)

    expect(client_guards).to match_array([false, false]) # les deux pré-vérifications passent
    expect(persisted.count).to eq(1)                     # le contrat : un seul CRA
    expect(outcomes.count(&:success?)).to eq(1)          # le premier : 201 success
    expect(outcomes.reject(&:success?)).to contain_exactly(
      an_object_having_attributes(error: :cra_already_exists) # le second : 409 contractuel
    )
  end
end