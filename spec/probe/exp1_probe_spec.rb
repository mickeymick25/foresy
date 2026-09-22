# frozen_string_literal: true

# BACKLOG #12 / EXP-1 — probe temporaire (jamais mergée).
# Échoue volontairement en embarquant l'évidence EXP-1 — lisible dans le log
# du run (page publique) : GITHUB_SHA / GITHUB_REF / contenu checkouté.
# Supprimée à la clôture de #12.
require 'spec_helper'

RSpec.describe 'EXP-1 probe — arbre checkouté (BACKLOG #12)' do
  it 'produit l evidence et échoue volontairement pour la tracer' do
    marker = File.exist?('docs/technical/probe_marker.md') ? 'PRESENT' : 'ABSENT'
    raise(
      'EXP-1 EVIDENCE | ' \
      "GITHUB_SHA=#{ENV['GITHUB_SHA'].inspect} | " \
      "GITHUB_REF=#{ENV['GITHUB_REF'].inspect} | " \
      "marker=#{marker}"
    )
  end
end