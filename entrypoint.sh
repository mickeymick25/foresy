#!/bin/bash
set -e

# ============================================
# Foresy API - Entrypoint Script
# Gold Level - Simplified & Robust
# Supports: Docker Compose (local) + Render (production)
# ============================================

echo "=== Foresy API Entrypoint ==="
echo "RAILS_ENV: ${RAILS_ENV:-development}"
echo "Ruby: $(ruby -v | head -c 40)"

# ============================================
# Helper Functions
# ============================================

wait_for_db() {
  # Si DATABASE_URL est défini (Render, Heroku, etc.), extraire host/port
  if [ -n "$DATABASE_URL" ]; then
    echo "🔄 Using DATABASE_URL for connection..."

    # Extraire host et port de DATABASE_URL
    # Format: postgres://user:pass@host:port/dbname
    local db_host=$(echo "$DATABASE_URL" | sed -E 's/.*@([^:\/]+).*/\1/')
    local db_port=$(echo "$DATABASE_URL" | sed -E 's/.*:([0-9]+)\/.*/\1/')

    # Port par défaut si non spécifié
    db_port=${db_port:-5432}

    echo "   Database host: ${db_host}"
    echo "   Database port: ${db_port}"

    # Pour les services managés (Render), la DB est généralement prête
    # On fait un test simple avec Rails
    echo "🔄 Testing database connection..."

    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
      if bundle exec rails db:version > /dev/null 2>&1; then
        echo "✅ Database is ready!"
        return 0
      fi
      echo "   Attempt ${attempt}/${max_attempts}..."
      sleep 3
      attempt=$((attempt + 1))
    done

    echo "⚠️  Database connection test failed, but continuing..."
    return 0
  fi

  # Mode Docker Compose local (DB_HOST ou 'db' par défaut)
  local host="${DB_HOST:-db}"
  local port="${DB_PORT:-5432}"
  local max_attempts=30
  local attempt=1

  echo "🔄 Waiting for database at ${host}:${port}..."

  # Vérifier si pg_isready est disponible
  if command -v pg_isready > /dev/null 2>&1; then
    while [ $attempt -le $max_attempts ]; do
      if pg_isready -h "$host" -p "$port" -q 2>/dev/null; then
        echo "✅ Database is ready!"
        return 0
      fi
      echo "   Attempt ${attempt}/${max_attempts}..."
      sleep 2
      attempt=$((attempt + 1))
    done
  else
    # Fallback: utiliser nc ou attendre simplement
    echo "⚠️  pg_isready not found, using fallback method..."
    while [ $attempt -le $max_attempts ]; do
      if nc -z "$host" "$port" 2>/dev/null; then
        echo "✅ Database port is open!"
        sleep 2  # Attendre un peu que PostgreSQL soit vraiment prêt
        return 0
      fi
      echo "   Attempt ${attempt}/${max_attempts}..."
      sleep 2
      attempt=$((attempt + 1))
    done
  fi

  echo "❌ Database not ready after ${max_attempts} attempts"
  return 1
}

generate_secret() {
  if [ -z "$SECRET_KEY_BASE" ] && [ "$RAILS_ENV" != "production" ]; then
    export SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')
    echo "🔧 Generated temporary SECRET_KEY_BASE"
  fi
}

run_migrations() {
  if [ "$RAILS_ENV" = "production" ] && [ "$SKIP_MIGRATIONS" != "true" ]; then
    echo "🔄 Running database migrations..."
    if bundle exec rails db:migrate; then
      echo "✅ Migrations complete"
    else
      echo "⚠️  Migration failed or no pending migrations"
    fi
  fi
}

cleanup_pid() {
  if [ -f tmp/pids/server.pid ]; then
    rm -f tmp/pids/server.pid
    echo "🧹 Removed stale PID file"
  fi
}

# ============================================
# Main Execution
# ============================================

# Generate secret if needed
generate_secret

# Wait for database if running Rails commands
if [[ "$*" =~ (rails|rspec|rake|puma) ]]; then
  wait_for_db || {
    echo "⚠️  Continuing despite database check failure..."
  }
fi

# Run migrations in production
run_migrations

# Cleanup stale PID
cleanup_pid

# Execute command
echo "🚀 Executing: $*"
exec "$@"
