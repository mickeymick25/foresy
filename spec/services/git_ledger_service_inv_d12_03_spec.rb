# frozen_string_literal: true

# Contrat #28 (O-1) — INV-D12-03 : en test, GIT_LEDGER_REAL=true NE cible JAMAIS le
# chemin contractuel par défaut sans overlay (env résolu au boot OU const_set).
#
# Scénario sans contact utile avec le ledger réel : CRA NON verrouillé (draft) —
# - pré-fix (RED attendu) : l'échec vient de validate_cra! ('Git Ledger commit failed:
#   CRA must be locked') — l'assertion du message dédié échoue, zéro écriture Git ;
# - post-fix (GREEN) : la garde lève le message dédié AVANT tout appel Git.
# Invariant de non-altération : compteur de commits du ledger inchangé.
require 'rails_helper'

RSpec.describe 'GitLedgerService — INV-D12-03 : refus du réel sans overlay (contrat #28)' do
  let(:user) { create(:user) }
  let(:cra) { create(:cra, :with_creator, creator: user, year: 2026, month: 9, status: 'draft') }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GIT_LEDGER_REAL').and_return('true')
  end

  it 'refuse GIT_LEDGER_REAL=true contre le chemin par défaut — message dédié, avant tout appel Git' do
    count_before = GitLedgerRepository.info[:commit_count]

    expect { GitLedgerService.commit_cra_lock!(cra) }
      .to raise_error(GitLedgerService::GitLedgerError, /Real ledger without overlay/)

    expect(GitLedgerRepository.info[:commit_count]).to eq(count_before)
  end
end
