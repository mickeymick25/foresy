#!/usr/bin/env bash

# =============================================================================
# Validation des Dépendances Natives avec Système de Progression Avancé
# Ruby 3.4.8 + YJIT + Bundler 4.x
# =============================================================================
# Date: 26 décembre 2025
# PR: #8 - Rails 8.1.1 + Ruby 3.4.8 Migration
# Objectif: Valider la compatibilité avec progression en temps réel
# =============================================================================

# Vérifier que nous utilisons bash 4+
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "⚠️  Ce script nécessite bash 4.0 ou supérieur"
    echo "   Version actuelle: ${BASH_VERSION}"
    echo "   Sur macOS: brew install bash"
    # Continuer quand même avec des fonctionnalités réduites
fi

# Désactiver set -e pour gérer les erreurs manuellement
set +e

# =============================================================================
# CONFIGURATION DES COULEURS
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# =============================================================================
# CONFIGURATION DU SYSTÈME DE PROGRESSION
# =============================================================================

# Structure des sections avec leurs poids (total = 100%)
declare -a SECTION_NAMES=("environment_check" "gems_identification" "gems_compilation" "yjit_performance" "security_audit" "memory_stress")
declare -a SECTION_WEIGHTS=(5 10 40 30 10 5)
declare -a SECTION_LABELS=("Environment Check" "Gems Identification" "Gems Compilation" "YJIT Performance" "Security Audit" "Memory Stress")

# Variables de tracking globales
GLOBAL_START_TIME=$(date +%s)
TOTAL_WEIGHT=100
CURRENT_SECTION_INDEX=0
CURRENT_SECTION_PROGRESS=0
COMPLETED_WEIGHT=0

# Compteurs de résultats (compatibilité bash 3.x)
# Utiliser des variables simples au lieu de tableaux associatifs
RESULTS_SUCCESS_environment_check=0
RESULTS_SUCCESS_gems_identification=0
RESULTS_SUCCESS_gems_compilation=0
RESULTS_SUCCESS_yjit_performance=0
RESULTS_SUCCESS_security_audit=0
RESULTS_SUCCESS_memory_stress=0

RESULTS_WARNING_environment_check=0
RESULTS_WARNING_gems_identification=0
RESULTS_WARNING_gems_compilation=0
RESULTS_WARNING_yjit_performance=0
RESULTS_WARNING_security_audit=0
RESULTS_WARNING_memory_stress=0

RESULTS_ERROR_environment_check=0
RESULTS_ERROR_gems_identification=0
RESULTS_ERROR_gems_compilation=0
RESULTS_ERROR_yjit_performance=0
RESULTS_ERROR_security_audit=0
RESULTS_ERROR_memory_stress=0

# Fonction pour incrémenter les compteurs
increment_success() {
    local section=$1
    eval "RESULTS_SUCCESS_${section}=\$((RESULTS_SUCCESS_${section} + 1))"
}

increment_warning() {
    local section=$1
    eval "RESULTS_WARNING_${section}=\$((RESULTS_WARNING_${section} + 1))"
}

increment_error() {
    local section=$1
    eval "RESULTS_ERROR_${section}=\$((RESULTS_ERROR_${section} + 1))"
}

get_success() {
    local section=$1
    eval "echo \$RESULTS_SUCCESS_${section}"
}

get_warning() {
    local section=$1
    eval "echo \$RESULTS_WARNING_${section}"
}

get_error() {
    local section=$1
    eval "echo \$RESULTS_ERROR_${section}"
}

# =============================================================================
# INITIALISATION DES LOGS
# =============================================================================

mkdir -p scripts/logs
LOG_FILE="scripts/logs/native_dependencies_validation_progress_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR="scripts/temp_validation_$$"
mkdir -p "$TEMP_DIR"

# Redirection des logs
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

# =============================================================================
# FONCTIONS DE PROGRESSION
# =============================================================================

# Créer une barre de progression visuelle
create_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-40}

    if [ "$total" -eq 0 ]; then
        total=1
    fi

    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done

    printf "[%s] %3d%%" "$bar" "$percentage"
}

# Formater le temps en HH:MM:SS
format_time() {
    local seconds=$1
    printf "%02d:%02d:%02d" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
}

# Calculer le pourcentage global
calculate_global_percentage() {
    local section_idx=$CURRENT_SECTION_INDEX
    local section_progress=$CURRENT_SECTION_PROGRESS

    # Additionner les sections complétées
    local completed=0
    for ((i=0; i<section_idx; i++)); do
        completed=$((completed + SECTION_WEIGHTS[i]))
    done

    # Ajouter la progression de la section courante
    if [ "$section_idx" -lt "${#SECTION_WEIGHTS[@]}" ]; then
        local section_weight=${SECTION_WEIGHTS[$section_idx]}
        local section_contribution=$((section_weight * section_progress / 100))
        completed=$((completed + section_contribution))
    fi

    echo $completed
}

# Afficher la progression globale
display_global_progress() {
    local percentage=$(calculate_global_percentage)
    local current_time=$(date +%s)
    local elapsed=$((current_time - GLOBAL_START_TIME))

    # Estimer le temps restant
    local remaining=0
    if [ "$percentage" -gt 0 ]; then
        local total_estimated=$((elapsed * 100 / percentage))
        remaining=$((total_estimated - elapsed))
    fi

    local elapsed_fmt=$(format_time $elapsed)
    local remaining_fmt=$(format_time $remaining)

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}${BOLD}🔄 PROGRESSION GLOBALE${NC}                                                        ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  $(create_progress_bar $percentage 100 50) ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GRAY}⏱️  Écoulé: ${elapsed_fmt}${NC}  ${GRAY}|${NC}  ${GRAY}⏳ Restant estimé: ${remaining_fmt}${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Afficher la progression d'une section
display_section_progress() {
    local section_name=$1
    local current=$2
    local total=$3
    local label=$4

    if [ "$total" -eq 0 ]; then
        total=1
    fi

    local percentage=$((current * 100 / total))
    local bar=$(create_progress_bar $current $total 25)

    echo -e "${BLUE}📊 ${label}: ${bar} (${current}/${total})${NC}"
}

# Démarrer une nouvelle section
start_section() {
    local section_idx=$1
    local label=${SECTION_LABELS[$section_idx]}
    local weight=${SECTION_WEIGHTS[$section_idx]}

    CURRENT_SECTION_INDEX=$section_idx
    CURRENT_SECTION_PROGRESS=0

    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}🔍 SECTION $((section_idx + 1))/${#SECTION_NAMES[@]}: ${label} (${weight}% du total)${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Mettre à jour la progression de la section courante
update_section_progress() {
    local progress=$1
    CURRENT_SECTION_PROGRESS=$progress
}

# Terminer une section
end_section() {
    CURRENT_SECTION_PROGRESS=100
    display_global_progress
}

# =============================================================================
# FONCTIONS DE LOGGING
# =============================================================================

log_step() {
    local status=$1
    local message=$2
    local timestamp=$(date +%H:%M:%S)
    local section=${SECTION_NAMES[$CURRENT_SECTION_INDEX]}

    case $status in
        "SUCCESS")
            echo -e "${GREEN}✅ [${timestamp}] ${message}${NC}"
            increment_success "$section"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  [${timestamp}] ${message}${NC}"
            increment_warning "$section"
            ;;
        "ERROR")
            echo -e "${RED}❌ [${timestamp}] ${message}${NC}"
            increment_error "$section"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  [${timestamp}] ${message}${NC}"
            ;;
        "PROGRESS")
            echo -e "${PURPLE}🔄 [${timestamp}] ${message}${NC}"
            ;;
        "PENDING")
            echo -e "${GRAY}⏳ [${timestamp}] ${message}${NC}"
            ;;
    esac
}

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

cleanup() {
    rm -rf "$TEMP_DIR"
    rm -f performance_test_simple.rb memory_stress_test.rb 2>/dev/null
}

trap cleanup EXIT

# =============================================================================
# DÉBUT DU SCRIPT
# =============================================================================

echo ""
echo -e "${WHITE}${BOLD}================================================================================${NC}"
echo -e "${WHITE}${BOLD}🔍 VALIDATION DES DÉPENDANCES NATIVES - RUBY 3.4.8 + YJIT + BUNDLER 4.x${NC}"
echo -e "${WHITE}${BOLD}================================================================================${NC}"
echo -e "${GRAY}Date: $(date)${NC}"
echo -e "${GRAY}Log file: $LOG_FILE${NC}"
echo ""

display_global_progress

# =============================================================================
# SECTION 1: VÉRIFICATION DE L'ENVIRONNEMENT (5%)
# =============================================================================

start_section 0

# Étape 1/3: Ruby version
log_step "PROGRESS" "Vérification de la version Ruby..."
update_section_progress 10

ruby_version=$(ruby -v 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "  Ruby version: $ruby_version"
    if [[ $ruby_version == *"3.4"* ]]; then
        log_step "SUCCESS" "Ruby 3.4.x détecté"
    else
        log_step "WARNING" "Version Ruby inattendue: $ruby_version"
    fi
else
    log_step "ERROR" "Ruby non trouvé"
fi
update_section_progress 33

# Étape 2/3: Bundler version
log_step "PROGRESS" "Vérification de la version Bundler..."
bundler_version=$(bundle --version 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "  Bundler version: $bundler_version"
    if [[ $bundler_version == *"4."* ]] || [[ $bundler_version == *"2."* ]]; then
        log_step "SUCCESS" "Bundler compatible détecté"
    else
        log_step "WARNING" "Version Bundler inattendue"
    fi
else
    log_step "ERROR" "Bundler non trouvé"
fi
update_section_progress 66

# Étape 3/3: YJIT support
log_step "PROGRESS" "Vérification du support YJIT..."
yjit_status=$(ruby -e "puts defined?(RubyVM::YJIT) ? 'enabled' : 'disabled'" 2>/dev/null)
if [ "$yjit_status" = "enabled" ]; then
    log_step "SUCCESS" "YJIT supporté et disponible"
else
    log_step "WARNING" "YJIT non disponible (performances réduites)"
fi
update_section_progress 100

end_section

# =============================================================================
# SECTION 2: IDENTIFICATION DES GEMS AVEC EXTENSIONS NATIVES (10%)
# =============================================================================

start_section 1

# Liste des gems avec extensions natives à vérifier
NATIVE_GEMS=("pg" "nokogiri" "bcrypt" "puma" "json" "ffi" "websocket-driver" "msgpack" "bootsnap" "nio4r")

# Utiliser des variables simples pour stocker les gems trouvées
FOUND_GEMS_LIST=""
FOUND_GEMS_COUNT=0
TOTAL_GEMS=${#NATIVE_GEMS[@]}
CURRENT_GEM=0

log_step "PROGRESS" "Scan de ${TOTAL_GEMS} gems avec extensions natives..."
echo ""

for gem in "${NATIVE_GEMS[@]}"; do
    CURRENT_GEM=$((CURRENT_GEM + 1))
    progress=$((CURRENT_GEM * 100 / TOTAL_GEMS))

    display_section_progress "gems_identification" $CURRENT_GEM $TOTAL_GEMS "Identification des gems"

    gem_info=$(bundle info "$gem" 2>/dev/null)
    if [ $? -eq 0 ]; then
        gem_version=$(echo "$gem_info" | grep -E "^\s+\* " | head -1 | sed 's/.*(\(.*\))/\1/' | awk '{print $NF}' | tr -d '()')
        if [ -z "$gem_version" ]; then
            gem_version=$(bundle info "$gem" --version 2>/dev/null | tail -1)
        fi
        # Stocker dans une liste simple
        FOUND_GEMS_LIST="${FOUND_GEMS_LIST}${gem}:${gem_version} "
        FOUND_GEMS_COUNT=$((FOUND_GEMS_COUNT + 1))
        eval "FOUND_GEM_${gem//-/_}='${gem_version}'"
        log_step "SUCCESS" "$gem: trouvé (version: $gem_version)"
    else
        log_step "INFO" "$gem: non installé"
    fi

    update_section_progress $progress
done

echo ""
log_step "SUCCESS" "Total des gems avec extensions natives trouvées: ${FOUND_GEMS_COUNT}/${TOTAL_GEMS}"

# Vérification bundle check
log_step "PROGRESS" "Validation des dépendances avec bundle check..."
bundle check > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_step "SUCCESS" "Toutes les dépendances sont satisfaites"
else
    log_step "WARNING" "Certaines dépendances peuvent nécessiter une installation"
fi

end_section

# =============================================================================
# SECTION 3: TESTS DE COMPILATION DES EXTENSIONS (40%)
# =============================================================================

start_section 2

SUCCESS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Convertir la liste de gems trouvées en tableau
GEMS_TO_TEST=()
for gem_entry in $FOUND_GEMS_LIST; do
    gem_name="${gem_entry%%:*}"
    if [ -n "$gem_name" ]; then
        GEMS_TO_TEST+=("$gem_name")
    fi
done
TOTAL_TO_TEST=${#GEMS_TO_TEST[@]}

if [ $TOTAL_TO_TEST -eq 0 ]; then
    log_step "WARNING" "Aucune gem avec extension native à tester"
    TOTAL_TO_TEST=1
fi

CURRENT_TEST=0

echo ""
echo -e "${BLUE}📦 Test de compilation de ${TOTAL_TO_TEST} gems...${NC}"
echo ""

for gem in "${GEMS_TO_TEST[@]}"; do
    [ -z "$gem" ] && continue

    CURRENT_TEST=$((CURRENT_TEST + 1))
    progress=$((CURRENT_TEST * 100 / TOTAL_TO_TEST))

    # Récupérer la version de la gem
    gem_var_name="FOUND_GEM_${gem//-/_}"
    eval "gem_version=\$$gem_var_name"

    echo ""
    display_section_progress "gems_compilation" $CURRENT_TEST $TOTAL_TO_TEST "Compilation des gems"
    log_step "PROGRESS" "Test compilation: $gem v${gem_version} (${CURRENT_TEST}/${TOTAL_TO_TEST})"

    # Test 1: bundle pristine
    bundle pristine "$gem" > "$TEMP_DIR/pristine_${gem}.log" 2>&1
    pristine_result=$?

    # Test 2: require test
    ruby -e "require '$gem'" > "$TEMP_DIR/require_${gem}.log" 2>&1
    require_result=$?

    if [ $pristine_result -eq 0 ] && [ $require_result -eq 0 ]; then
        log_step "SUCCESS" "$gem: Compilation ✓ | Require ✓"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [ $pristine_result -eq 0 ]; then
        log_step "WARNING" "$gem: Compilation ✓ | Require ✗"
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        # Tentative de réinstallation
        gem install "$gem" --no-document > "$TEMP_DIR/install_${gem}.log" 2>&1
        if [ $? -eq 0 ]; then
            ruby -e "require '$gem'" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                log_step "SUCCESS" "$gem: Réinstallation réussie"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                log_step "WARNING" "$gem: Installé mais require échoue"
                WARN_COUNT=$((WARN_COUNT + 1))
            fi
        else
            log_step "ERROR" "$gem: Échec de compilation"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi

    update_section_progress $progress
done

echo ""
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}📊 RÉSUMÉ COMPILATION:${NC}"
echo -e "  ${GREEN}✅ Succès: ${SUCCESS_COUNT}${NC}"
echo -e "  ${YELLOW}⚠️  Avertissements: ${WARN_COUNT}${NC}"
echo -e "  ${RED}❌ Échecs: ${FAIL_COUNT}${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

end_section

# =============================================================================
# SECTION 4: TESTS DE PERFORMANCE YJIT (30%)
# =============================================================================

start_section 3

# Créer le script de test de performance
cat > "$TEMP_DIR/performance_test.rb" << 'RUBY_PERF_EOF'
require 'benchmark'
require 'json'

def test_json_performance(iterations)
  data = {"test" => "data", "items" => (1..100).to_a, "nested" => {"a" => 1, "b" => 2}}
  json_string = data.to_json

  iterations.times do
    JSON.parse(json_string)
  end
end

def test_string_performance(iterations)
  string = "hello world " * 100

  iterations.times do
    s = string.dup
    s.upcase!
    s.downcase!
    s.split(' ')
  end
end

def test_array_performance(iterations)
  array = (1..200).to_a

  iterations.times do
    a = array.dup
    a.shuffle!
    a.sort!
    a.map { |x| x * 2 }
  end
end

def test_hash_performance(iterations)
  iterations.times do
    h = {}
    100.times { |i| h[i.to_s] = i * 2 }
    h.values.sum
  end
end

puts "=== Ruby Performance Test ==="
puts "Ruby version: #{RUBY_VERSION}"
puts "YJIT status: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'ENABLED' : 'DISABLED'}"
puts ""

ITERATIONS = 5000

results = {}

Benchmark.bm(20) do |x|
  results[:json] = x.report("JSON parsing:") { test_json_performance(ITERATIONS) }
  results[:string] = x.report("String ops:") { test_string_performance(ITERATIONS) }
  results[:array] = x.report("Array ops:") { test_array_performance(ITERATIONS) }
  results[:hash] = x.report("Hash ops:") { test_hash_performance(ITERATIONS) }
end

total_time = results.values.map(&:real).sum
puts ""
puts "Total execution time: #{total_time.round(3)} seconds"
puts "Average per test: #{(total_time / 4).round(3)} seconds"
RUBY_PERF_EOF

# Test 1/4: Test avec YJIT activé
log_step "PROGRESS" "Test de performance avec YJIT activé..."
update_section_progress 10

export RUBY_YJIT_ENABLE=1
ruby --yjit "$TEMP_DIR/performance_test.rb" > "scripts/logs/yjit_performance.log" 2>&1
yjit_exit=$?

if [ $yjit_exit -eq 0 ]; then
    log_step "SUCCESS" "Tests YJIT complétés"
    yjit_time=$(grep "Total execution time" "scripts/logs/yjit_performance.log" | awk '{print $4}')
    echo -e "  ${GRAY}Temps total YJIT: ${yjit_time}s${NC}"
else
    log_step "WARNING" "Tests YJIT avec erreurs (voir log)"
fi
update_section_progress 35

# Test 2/4: Test sans YJIT
log_step "PROGRESS" "Test de performance sans YJIT..."
export RUBY_YJIT_ENABLE=0
ruby --disable-yjit "$TEMP_DIR/performance_test.rb" > "scripts/logs/no_yjit_performance.log" 2>&1
no_yjit_exit=$?

if [ $no_yjit_exit -eq 0 ]; then
    log_step "SUCCESS" "Tests sans YJIT complétés"
    no_yjit_time=$(grep "Total execution time" "scripts/logs/no_yjit_performance.log" | awk '{print $4}')
    echo -e "  ${GRAY}Temps total sans YJIT: ${no_yjit_time}s${NC}"
else
    log_step "WARNING" "Tests sans YJIT avec erreurs"
fi
update_section_progress 60

# Test 3/4: Comparaison
log_step "PROGRESS" "Analyse comparative des performances..."

if [ -n "$yjit_time" ] && [ -n "$no_yjit_time" ]; then
    # Calculer l'amélioration (utiliser bc pour les calculs flottants)
    if command -v bc &> /dev/null; then
        improvement=$(echo "scale=2; (($no_yjit_time - $yjit_time) / $no_yjit_time) * 100" | bc 2>/dev/null)
        if [ -n "$improvement" ]; then
            echo ""
            echo -e "${GREEN}📈 YJIT Performance Improvement: ${improvement}%${NC}"
            log_step "SUCCESS" "Amélioration YJIT: ${improvement}%"
        fi
    else
        log_step "INFO" "bc non disponible pour le calcul d'amélioration"
    fi
else
    log_step "WARNING" "Impossible de calculer l'amélioration YJIT"
fi
update_section_progress 80

# Test 4/4: Validation finale performance
log_step "PROGRESS" "Validation finale des performances..."
if [ $yjit_exit -eq 0 ] && [ $no_yjit_exit -eq 0 ]; then
    log_step "SUCCESS" "Tous les tests de performance réussis"
else
    log_step "WARNING" "Certains tests de performance ont échoué"
fi
update_section_progress 100

end_section

# =============================================================================
# SECTION 5: SÉCURITÉ ET AUDIT (10%)
# =============================================================================

start_section 4

# Test 1/3: Bundle audit
log_step "PROGRESS" "Exécution de bundle audit..."
update_section_progress 10

if command -v bundle-audit &> /dev/null || bundle audit --help > /dev/null 2>&1; then
    bundle audit check --update > "scripts/logs/bundle_audit.log" 2>&1
    audit_exit=$?

    if [ $audit_exit -eq 0 ]; then
        log_step "SUCCESS" "Aucune vulnérabilité de sécurité détectée"
    else
        vuln_count=$(grep -c "CVE-" "scripts/logs/bundle_audit.log" 2>/dev/null || echo "0")
        log_step "WARNING" "${vuln_count} vulnérabilité(s) potentielle(s) détectée(s)"
        echo -e "  ${GRAY}Voir scripts/logs/bundle_audit.log pour détails${NC}"
    fi
else
    log_step "INFO" "bundle-audit non installé, skip audit de sécurité"
    audit_exit=0
fi
update_section_progress 40

# Test 2/3: Gems obsolètes
log_step "PROGRESS" "Vérification des gems obsolètes..."
bundle outdated --strict > "scripts/logs/bundle_outdated.log" 2>&1
outdated_exit=$?

if [ $outdated_exit -eq 0 ]; then
    log_step "SUCCESS" "Toutes les gems sont à jour"
else
    outdated_count=$(grep -c "  \* " "scripts/logs/bundle_outdated.log" 2>/dev/null)
    if [ -z "$outdated_count" ] || [ "$outdated_count" -eq 0 ]; then
        outdated_count="plusieurs"
    fi
    log_step "INFO" "${outdated_count} gem(s) avec mises à jour disponibles"
fi
update_section_progress 70

# Test 3/3: Validation Gemfile.lock
log_step "PROGRESS" "Validation du Gemfile.lock..."
if [ -f "Gemfile.lock" ]; then
    bundle check > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_step "SUCCESS" "Gemfile.lock valide et synchronisé"
    else
        log_step "WARNING" "Gemfile.lock nécessite une mise à jour"
    fi
else
    log_step "ERROR" "Gemfile.lock non trouvé"
fi
update_section_progress 100

end_section

# =============================================================================
# SECTION 6: TESTS DE CHARGE MÉMOIRE (5%)
# =============================================================================

start_section 5

# Créer le script de test mémoire
cat > "$TEMP_DIR/memory_stress.rb" << 'RUBY_MEM_EOF'
require 'json'

def get_memory_mb
  `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
end

def stress_test
  puts "=== Memory Stress Test ==="

  GC.start
  baseline = get_memory_mb
  puts "Baseline memory: #{baseline.round(2)} MB"

  # Stress test: créer beaucoup d'objets
  data = []
  10.times do |round|
    1000.times do |i|
      data << {
        id: i,
        round: round,
        data: "x" * 100,
        timestamp: Time.now.to_s
      }
    end

    # Convertir en JSON et parser
    json = data.to_json
    parsed = JSON.parse(json)

    current = get_memory_mb
    puts "Round #{round + 1}/10: Memory #{current.round(2)} MB (growth: #{(current - baseline).round(2)} MB)"
  end

  # Cleanup
  data = nil
  GC.start
  sleep 0.1
  GC.start

  final = get_memory_mb
  puts ""
  puts "Final memory after GC: #{final.round(2)} MB"
  puts "Net growth: #{(final - baseline).round(2)} MB"

  # Vérifier si la croissance est acceptable
  growth = final - baseline
  if growth < 50
    puts "✅ Memory growth acceptable (< 50 MB)"
    exit 0
  elsif growth < 100
    puts "⚠️ Memory growth moderate (< 100 MB)"
    exit 0
  else
    puts "❌ Memory growth excessive (> 100 MB)"
    exit 1
  end
end

stress_test
RUBY_MEM_EOF

log_step "PROGRESS" "Exécution des tests de charge mémoire..."
update_section_progress 20

ruby "$TEMP_DIR/memory_stress.rb" > "scripts/logs/memory_stress.log" 2>&1
memory_exit=$?

update_section_progress 70

if [ $memory_exit -eq 0 ]; then
    log_step "SUCCESS" "Tests de charge mémoire réussis"

    # Extraire les informations de mémoire
    baseline=$(grep "Baseline memory:" "scripts/logs/memory_stress.log" | awk '{print $3}')
    final=$(grep "Final memory after GC:" "scripts/logs/memory_stress.log" | awk '{print $5}')
    growth=$(grep "Net growth:" "scripts/logs/memory_stress.log" | awk '{print $3}')

    echo -e "  ${GRAY}Mémoire baseline: ${baseline} MB${NC}"
    echo -e "  ${GRAY}Mémoire finale: ${final} MB${NC}"
    echo -e "  ${GRAY}Croissance nette: ${growth} MB${NC}"
else
    log_step "WARNING" "Tests mémoire avec avertissements"
fi

update_section_progress 100

end_section

# =============================================================================
# RAPPORT FINAL
# =============================================================================

echo ""
echo -e "${WHITE}${BOLD}================================================================================${NC}"
echo -e "${WHITE}${BOLD}📊 RAPPORT FINAL DE VALIDATION${NC}"
echo -e "${WHITE}${BOLD}================================================================================${NC}"
echo ""

# Temps total
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - GLOBAL_START_TIME))
TOTAL_TIME_FMT=$(format_time $TOTAL_TIME)

echo -e "${CYAN}⏱️  Temps total d'exécution: ${TOTAL_TIME_FMT}${NC}"
echo ""

# Progression finale
display_global_progress

# Résumé par section
echo -e "${WHITE}${BOLD}📋 RÉSUMÉ PAR SECTION:${NC}"
echo ""

for i in "${!SECTION_NAMES[@]}"; do
    section=${SECTION_NAMES[$i]}
    label=${SECTION_LABELS[$i]}
    weight=${SECTION_WEIGHTS[$i]}

    success=$(get_success "$section")
    warning=$(get_warning "$section")
    error=$(get_error "$section")

    # Valeurs par défaut si vide
    success=${success:-0}
    warning=${warning:-0}
    error=${error:-0}

    # Déterminer l'icône de statut
    if [ "$error" -gt 0 ]; then
        icon="❌"
        color=$RED
    elif [ "$warning" -gt 0 ]; then
        icon="⚠️ "
        color=$YELLOW
    else
        icon="✅"
        color=$GREEN
    fi

    printf "  ${color}${icon} %-25s [%3d%%] ✓%d ⚠%d ✗%d${NC}\n" "$label:" "$weight" "$success" "$warning" "$error"
done

echo ""

# Résumé environnement
echo -e "${WHITE}${BOLD}🔧 ENVIRONNEMENT:${NC}"
echo -e "  • Ruby: $(ruby --version 2>/dev/null | head -1)"
echo -e "  • Bundler: $(bundle --version 2>/dev/null)"
echo -e "  • YJIT: $(ruby -e "puts defined?(RubyVM::YJIT) ? 'Disponible' : 'Non disponible'" 2>/dev/null)"
echo ""

# Résumé compilation
echo -e "${WHITE}${BOLD}📦 COMPILATION GEMS:${NC}"
echo -e "  • Gems testées: ${#FOUND_GEMS[@]}"
echo -e "  • ${GREEN}Succès: ${SUCCESS_COUNT}${NC}"
echo -e "  • ${YELLOW}Avertissements: ${WARN_COUNT}${NC}"
echo -e "  • ${RED}Échecs: ${FAIL_COUNT}${NC}"
echo ""

# Statut global
echo -e "${WHITE}${BOLD}🎯 STATUT GLOBAL:${NC}"

# Calculer le statut final
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
for section in "${SECTION_NAMES[@]}"; do
    section_errors=$(get_error "$section")
    section_warnings=$(get_warning "$section")
    TOTAL_ERRORS=$((TOTAL_ERRORS + ${section_errors:-0}))
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + ${section_warnings:-0}))
done

if [ $TOTAL_ERRORS -eq 0 ] && [ $FAIL_COUNT -eq 0 ]; then
    if [ $TOTAL_WARNINGS -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║     ✅ VALIDATION RÉUSSIE - TOUTES LES DÉPENDANCES NATIVES SONT OK          ║${NC}"
        echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}🚀 PRÊT POUR PRODUCTION${NC}"
        FINAL_STATUS=0
    else
        echo ""
        echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}${BOLD}║    ⚠️  VALIDATION AVEC AVERTISSEMENTS - SURVEILLANCE RECOMMANDÉE            ║${NC}"
        echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}🔧 Actions recommandées:${NC}"
        echo "  • Réviser les avertissements ci-dessus"
        echo "  • Mettre en place un monitoring renforcé"
        FINAL_STATUS=1
    fi
else
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║       ❌ VALIDATION ÉCHOUÉE - CORRECTIFS REQUIS AVANT DÉPLOIEMENT            ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}🚨 Actions requises:${NC}"
    echo "  • Corriger les ${TOTAL_ERRORS} erreur(s) détectée(s)"
    echo "  • Recompiler les ${FAIL_COUNT} gem(s) en échec"
    echo "  • Relancer la validation après corrections"
    FINAL_STATUS=2
fi

echo ""

# Fichiers générés
echo -e "${WHITE}${BOLD}📁 FICHIERS GÉNÉRÉS:${NC}"
echo "  • Log principal: $LOG_FILE"
echo "  • Performance YJIT: scripts/logs/yjit_performance.log"
echo "  • Performance sans YJIT: scripts/logs/no_yjit_performance.log"
echo "  • Bundle audit: scripts/logs/bundle_audit.log"
echo "  • Bundle outdated: scripts/logs/bundle_outdated.log"
echo "  • Stress test mémoire: scripts/logs/memory_stress.log"
echo ""

echo "================================================================================"
echo "Validation terminée à $(date)"
echo "================================================================================"

exit $FINAL_STATUS
