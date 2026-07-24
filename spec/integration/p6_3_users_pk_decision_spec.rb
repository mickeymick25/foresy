# frozen_string_literal: true

# P6.3 — Décision architecturale : users PK reste en bigint
#
# Audit point D1: users est la seule table avec PK bigint au lieu d'UUID.
# Après évaluation, la migration vers UUID serait :
# - Effort élevé (4-8h, migration en 3 étapes avec backfill)
# - Risque élevé (impacte users, sessions, user_missions, user_cras,
#   created_by_user_id dans missions et cras)
# - Bénéfice limité (les UUID PK sont meilleurs pour la sécurité/obscurcité
#   mais le projet expose déjà les UUID via la colonne `users.uuid`)
#
# Décision : Documenter comme choix architectural délibéré.
# La colonne `users.uuid` (UUID natif depuis P5.1) sert d'identifiant public.
# Le PK bigint reste l'identifiant interne pour les performances des joins.

require 'rails_helper'

RSpec.describe 'P6.3 — users PK bigint decision' do
  it 'users PK is bigint (deliberate architectural choice)' do
    column = User.columns_hash['id']
    expect(column.sql_type).to match(/integer|bigint/)
  end

  it 'users has a separate uuid column for public identification' do
    column = User.columns_hash['uuid']
    expect(column.sql_type).to eq('uuid')
  end
end
