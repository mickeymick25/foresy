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
# fichiers/dossiers explicites ou filtré (--pattern, -e, -t) garde la mesure et
# les rapports, sans échec au seuil.
#
# Décisions CTO (17→18/09) :
# - 17/09 : baseline mesurée x2 à 73,21 % lignes / 45,07 % branches (962 exemples,
#   corpus conteneur lazy). Trajectoire : 95 % avec palier décisionnel à 90 % (P6.6).
# - 18/09 (recalibration temporaire bornée) : le corpus d'enforcement CI (eager
#   load, ENV['CI']) post-cleanup est mesuré à 72,34 % — l'écart vs lazy est le
#   chemin OAuth code-exchange (`o_auth_code_exchange_service.rb` : code de
#   production non testé, appelé par OAuthValidationService.extract_oauth_data),
#   transféré à P6 Wave 2. Seuil TRANSITOIRE 72,0 (marge +0,34 pt sur corpus CI) :
#   ce n'est PAS un baseline qualitatif ; le retour à 72,5 est explicitement
#   rattaché à la couverture de ce fichier en Wave 2 (premier travail de Wave 2).
#   Aucune exclusion SimpleCov pour lui — le gap doit rester visible.
#   L'objectif 95 % reste inchangé. Branch coverage : P6.6.
# - 20/09 (Wave 2 livrée) : OAuthCodeExchangeService caractérisé — W2-D2 : 10 specs stub
#   Net::HTTP uniquement, service 0 % → 69,44 % lignes / 13/29 branches (asymétries uid
#   Integer/to_s et transports post_form vs perform_https_request documentées) · W2-D3 :
#   7 specs requête end-to-end (users réels + JWT réels {user_id, provider, exp}) —
#   994/0 · 77,83 % lignes / 48,42 % branches. Divergence mineure documentée :
#   format_success_response inclut 'name' (absent du schéma RSwag) — caractérisée,
#   sans correction produit. Verrou restauré 72,5 (GO CTO — marge +5,33 pts).
# P6.1-bis — garde --pattern (incident #4, job CI « Contracts ») : le RakeTask
# de rswag (`rake rswag:specs:swaggerize`) invoque rspec avec `--pattern <globs>`
# SANS argument de fichier — files_or_directories vaut alors [default_path] et
# les filtres sont vides, et le verdict « suite complète » armerait le verrou
# sur un subset (404 exemples verts, 47,94 %, exit 2). rspec applique --pattern
# à la configuration AVANT de charger les --require : un snapshot au boot est
# donc inopérant. La comparaison se fait donc à l'at_exit contre une instance
# fraîche de Configuration, dont pattern/exclude_pattern lazy-initialisés
# valent les DÉFAUTS réels de la version courante — sans hardcodage, et
# fail-closed si l'API dérive.

at_exit do
  # rspec-core 3.13 : le getter `files_or_directories_to_run` n'est plus exposé —
  # l'ivar posée par le setter reste la source de vérité. Sans argument, RSpec
  # l'initialise à [default_path]. Un filtrage par nom (`-e`/--example), par
  # tag (`-t`) ou par glob (`--pattern`, ex. RakeTask rswag) résout aussi
  # [default_path] tout en n'exécutant qu'une sous-partie → vérifiés séparément
  # via full_description/inclusion_filter et les snapshots de patterns.
  # Si l'API dérive (comparaison qui ne matche plus), le verrou s'arme : fail-closed,
  # un garde-fou de régression ne fail-ouvre pas.
  explicit_files = RSpec.configuration.instance_variable_get(:@files_or_directories_to_run)
  fresh_defaults = RSpec::Core::Configuration.new
  full_suite = explicit_files == [RSpec.configuration.default_path] &&
               RSpec.configuration.full_description.nil? &&
               RSpec.configuration.inclusion_filter.empty? &&
               RSpec.configuration.pattern == fresh_defaults.pattern &&
               RSpec.configuration.exclude_pattern == fresh_defaults.exclude_pattern
  SimpleCov.minimum_coverage line: 72.5 if full_suite
end
