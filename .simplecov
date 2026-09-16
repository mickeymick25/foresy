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
