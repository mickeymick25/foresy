# frozen_string_literal: true

require 'rails_helper'

# W3-D3 — Caractérisation de OAuthUserService : chemins vivants non couverts
# (tracker p6_wave3 §W3-D3 — arbitrage CTO 20/09 : valid_oauth_user_data? et
# find_existing_user supprimées, pas de spec pour du code supprimé)
RSpec.describe OAuthUserService do
  describe 'race condition — retry_find_after_race_condition' do
    let(:oauth_data) { { provider: 'github', uid: 'race-1', email: 'race1@foresy.dev', name: 'Race' } }

    it 'retourne l utilisateur retrouvé après la violation de contrainte' do
      create(:user, provider: 'github', uid: 'race-1', email: 'race1@foresy.dev')

      winner = described_class.retry_find_after_race_condition(oauth_data)

      expect(winner).to be_present
      expect(winner.email).to eq('race1@foresy.dev')
    end

    it 'lève RecordNotFound si l utilisateur est introuvable après retry' do
      expect { described_class.retry_find_after_race_condition(oauth_data) }
        .to raise_error(ActiveRecord::RecordNotFound, /OAuth user not found after race condition/)
    end
  end

  describe 'liaison par email (find_by_email_and_link_provider + update_existing_oauth_user!)' do
    it 'lie un nouveau provider à un utilisateur existant et met à jour ses données' do
      existing = create(:user, email: 'legacy@foresy.dev', password: 'password123',
                               password_confirmation: 'password123')

      oauth_data = { provider: 'google_oauth2', uid: 'google-new-1',
                     email: 'legacy@foresy.dev', name: 'Legacy via Google' }
      result = described_class.find_or_create_user_from_oauth(oauth_data)

      expect(result.id).to eq(existing.id)
      result.reload
      expect(result.provider).to eq('google_oauth2')
      expect(result.uid).to eq('google-new-1')
      expect(result.name).to eq('Legacy via Google')
      expect(result.active).to be(true)
    end

    it 're-raised RecordInvalid quand la création viole une validation (uid manquant)' do
      conflicting = { provider: 'github', uid: nil, email: 'unique@foresy.dev', name: 'X' }

      expect { described_class.find_or_create_user_from_oauth(conflicting) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'find_by_email_and_link_provider — utilisateur introuvable' do
    it 'retourne nil sans lever (délegation au create)' do
      expect(described_class.find_by_email_and_link_provider(
               provider: 'github', uid: 'no-match-1', email: 'absent@foresy.dev'
             )).to be_nil
    end
  end
end
