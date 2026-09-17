#!/usr/bin/env ruby
# frozen_string_literal: true

# P6.0 — Analyse exhaustive des manques de couverture (outil versionné)
#
# Usage (après une suite complète, conteneur, base foresy_test) :
#   docker compose exec -T web sh -c \
#     "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test \
#      RAILS_ENV=test bundle exec rspec"
#   docker compose exec -T web ruby scripts/coverage_gap_analysis.rb
#
# Entrée : coverage/.resultset.json (généré par SimpleCov 1.3.0 —
#   enable_coverage :branch, filtres/groupes définis dans .simplecov)
# Sortie : synthèse, tous les fichiers avec lignes non couvertes (tri : manque
#   décroissant), scénarios de progression 80/85/90/95 %
# Référence : docs/technical/changes/2026-09-17-P6_Coverage_Gap_Analysis.md
#
# Le périmètre est celui des filtres .simplecov (code applicatif app/ uniquement ;
# spec/, config/, db/, bin/, vendor/, node_modules/, __test_support__/ exclus).
# Les E2E shell n'y contribuent pas (process serveur ≠ process RSpec).

require 'json'

rs = JSON.parse(File.read('coverage/.resultset.json'))
cov = rs.values.first['coverage']

files = []
cov.each do |file, data|
  next unless file.include?('/app/')

  lines = data['lines'].compact
  rel = lines.count { |n| n > 0 }
  btot = 0
  brel = 0
  (data['branches'] || {}).each_value do |arms|
    arms.each_value do |hits|
      Array(hits).each do |h|
        btot += 1
        brel += 1 if h && h > 0
      end
    end
  end
  files << { path: file.sub('/app/', ''), rel: rel, tot: lines.size, unc: lines.size - rel,
             brel: brel, btot: btot }
end

tot_lines = files.sum { |f| f[:tot] }
cov_lines = files.sum { |f| f[:rel] }
tot_unc = tot_lines - cov_lines

puts '=== SYNTHÈSE ==='
puts "lignes: #{cov_lines}/#{tot_lines} (#{(cov_lines * 100.0 / tot_lines).round(2)}%) — non couvertes: #{tot_unc}"
puts "fichiers avec écarts: #{files.count { |f| f[:unc].positive? }} / #{files.size}"

puts "\n=== TOUS les fichiers avec lignes non couvertes (tri : manque décroissant) ==="
puts format('%-4s %-6s %-6s %-6s %-11s %-10s %s', '#', 'l%', 'unc', 'tot', 'branches', 'bunc', 'fichier')
files.select { |f| f[:unc].positive? }.sort_by { |f| -f[:unc] }.each_with_index do |f, i|
  bpct = f[:btot].zero? ? 0.0 : (f[:brel] * 100.0 / f[:btot]).round(1)
  puts format('%-4d %-6.1f %-6d %-6d %-11s %-10d %s', i + 1, f[:rel] * 100.0 / f[:tot],
              f[:unc], f[:tot], "#{f[:brel]}/#{f[:btot]} (#{bpct}%)", f[:btot] - f[:brel], f[:path])
end

puts "\n=== SCÉNARIOS DE PROGRESSION (objectif global en % lignes) ==="
sorted = files.select { |f| f[:unc].positive? }.sort_by { |f| -f[:unc] }
[80, 85, 90, 95].each do |target|
  need = (tot_lines * target / 100.0).round - cov_lines
  gained = 0
  used = []
  sorted.each do |f|
    break if gained >= need

    gained += f[:unc]
    used << f[:path]
  end
  puts format('cible %d%% : +%-4d lignes à couvrir ≈ %-2d fichiers (top manques)', target, need, used.size)
end