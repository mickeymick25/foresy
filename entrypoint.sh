#!/bin/bash
set -e

# ============================================
# Foresy API - Entrypoint Script
# Gold Level - Simplified & Robust
# ============================================

echo "=== Foresy API Entrypoint ==="
echo "RAILS_ENV: ${RAILS_ENV:-development}"
echo "Ruby: $(ruby -v | head -c 30)"

# ============================================
# Helper Functions
# ============================================

wait_for_db() {
  local host="${DB_HOST:-db}"
  local port="${DB_PORT:-5432}"
  local max_attempts=30
  local attempt=1

  echo "🔄 Waiting for database at ${host}:${port}..."

  while [ $attempt -le $max_attempts ]; do
    if pg_isready -h "$host" -p "$port" -q 2>/dev/null; then
      echo "✅ Database is ready!"
      return 0
    fi
    echo "   Attempt ${attempt}/${max_attempts}..."
    sleep 2
    attempt=$((attempt + 1))
  done

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
    bundle exec rails db:migrate
    echo "✅ Migrations complete"
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
  wait_for_db || exit 1
fi

# Run migrations in production
run_migrations

# Cleanup stale PID
cleanup_pid

# Execute command
echo "🚀 Executing: $*"
exec "$@"
