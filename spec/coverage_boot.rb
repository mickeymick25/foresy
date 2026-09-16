# frozen_string_literal: true

# D-2 — Boot SimpleCov : doit s'exécuter AVANT le chargement de l'application.
# Constat : .rspec chargeait ./config/environment en premier au boot — l'app se chargeait
# donc avant rails_helper/spec_helper, et un require 'simplecov' en tête de spec_helper
# serait arrivé trop tard (couverture vide). Ce boot garantit l'instrumentation de tout
# le code chargé ensuite. Requis via la directive --require de .rspec.
require 'simplecov'

require File.expand_path('../config/environment', __dir__)
