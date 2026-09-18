# frozen_string_literal: true

# D-2 — Couverture de lignes (SimpleCov)
# Auto-chargé par `require 'simplecov'` (voir spec/coverage_boot.rb — doit démarrer
# AVANT le chargement de l'application, cf. .rspec).
#
# Décisions actées (co-CTO 16/09) : D-2.1 baseline sans échec (pas de seuil dur en
# phase 1) · D-2.2 rapport Cobertura XML · seuil 95 % à décider APRÈS mesure (P6).
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  enable_coverage :branch

  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/vendor/'
  add_filter '/node_modules/'
  add_filter '/__test_support__/'

  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::CoberturaFormatter]
  )
end

# P6.1 — Verrou de couverture : suite complète uniquement (incident CI 17→18/09).
#
# `minimum_coverage` posé dans le bloc `start` s'appliquait à TOUT run rspec, y
# compris les runs partiels (gate DDD sur 2 fichiers, acceptance du job E2E,
# fichiers ciblés en local) : ceux-ci couvrent mécaniquement moins que la suite
# → SimpleCov sortait en exit 2 alors que les specs passaient → CI rouge.
#
# Le verdict « suite complète ? » ne peut pas être pris au boot : ce fichier est
# chargé par `require 'simplecov'` (cf. spec/coverage_boot.rb) AVANT que RSpec
# n'applique ses options. Le verrou est donc armé dans un at_exit enregistré
# APRÈS celui de SimpleCov (LIFO : il s'exécute AVANT), au moment où la
# configuration RSpec est certainement peuplée — SimpleCov relit le seuil à son
# tour dans son propre at_exit (build_coverage_limits). Un run avec
# fichiers/dossiers explicites garde la mesure et les rapports, sans échec au
# seuil.
#
# Décision CTO du 17/09 : baseline mesurée x2 à 73,21 % lignes / 45,07 % branches
# (962 exemples). Marge : 0,71 pt. Trajectoire : 95 % avec palier décisionnel à 90 %
# (P6.6). Branch coverage : P6.6.
at_exit do
  # rspec-core 3.13 : le getter `files_or_directories_to_run` n'est plus exposé —
  # l'ivar posée par le setter reste la source de vérité. Sans argument, RSpec
  # l'initialise à [default_path]. Un filtrage par nom (`-e`/--example) ou par
  # tag (`-t`) résout aussi [default_path] tout en n'exécutant qu'une sous-partie
  # → vérifiés séparément via full_description/inclusion_filter.
  # Si l'API dérive (comparaison qui ne matche plus), le verrou s'arme : fail-closed,
  # un garde-fou de régression ne fail-ouvre pas.
  explicit_files = RSpec.configuration.instance_variable_get(:@files_or_directories_to_run)
  full_suite = explicit_files == [RSpec.configuration.default_path] &&
               RSpec.configuration.full_description.nil? &&
               RSpec.configuration.inclusion_filter.empty?
  SimpleCov.minimum_coverage line: 72.5 if full_suite
end
