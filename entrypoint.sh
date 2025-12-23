#!/bin/bash
set -e

echo "=== Foresy API Entrypoint ==="
echo "RAILS_ENV: ${RAILS_ENV:-development}"

# Function to check if required environment variables are set
check_required_env_vars() {
  local missing_vars=()

  if [ "$RAILS_ENV" = "production" ]; then
    if [ -z "$DATABASE_URL" ] && [ -z "$DB_HOST" ]; then
      missing_vars+=("DATABASE_URL or DB_HOST/DB_USERNAME/DB_PASSWORD")
    fi

    if [ -z "$SECRET_KEY_BASE" ]; then
      missing_vars+=("SECRET_KEY_BASE")
    fi
  fi

  if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "❌ Missing required environment variables:"
    printf '   - %s\n' "${missing_vars[@]}"
    echo ""
    echo "For production, please set:"
    echo "  - DATABASE_URL (e.g., postgres://user:pass@host:5432/dbname)"
    echo "  - OR DB_HOST, DB_USERNAME, DB_PASSWORD, DB_DATABASE"
    echo "  - SECRET_KEY_BASE (32+ characters)"
    exit 1
  fi
}

# Function to wait for database to be ready
wait_for_database() {
  if [ -n "$DATABASE_URL" ]; then
    # Extract host and user from DATABASE_URL
    local db_host=$(echo "$DATABASE_URL" | sed -n 's|.*://[^@]*@\([^:/]*\).*|\1|p')
    local db_user=$(echo "$DATABASE_URL" | sed -n 's|.*://\([^:]*\).*|\1|p')
    db_user=${db_user:-postgres}
    local db_port=$(echo "$DATABASE_URL" | sed -n 's|.*@[^:]*:\([0-9]*\).*|\1|p')
    db_port=${db_port:-5432}
  else
    local db_host="${DB_HOST:-localhost}"
    local db_user="${DB_USERNAME:-postgres}"
    local db_port="${DB_PORT:-5432}"
  fi

  echo "🔄 Waiting for database at $db_host:$db_port..."

  local retries=30
  local count=0

  while [ $count -lt $retries ]; do
    if pg_isready -h "$db_host" -p "$db_port" -U "$db_user" >/dev/null 2>&1; then
      echo "✅ Database is ready!"
      return 0
    fi

    count=$((count + 1))
    echo "⏳ Database not ready yet (attempt $count/$retries)..."
    sleep 2
  done

  echo "❌ Database connection failed after $retries attempts"
  return 1
}

# Generate a temporary SECRET_KEY_BASE if not provided (development only)
generate_secret_key_base() {
  if [ -z "$SECRET_KEY_BASE" ] && [ "$RAILS_ENV" != "production" ]; then
    echo "🔧 Generating temporary SECRET_KEY_BASE for $RAILS_ENV..."
    export SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')
    echo "✅ Generated SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:20}..."
  fi
}

# Function to run database migrations with retry
run_migrations() {
  echo "🔄 Running database migrations..."

  local retries=3
  local count=0

  while [ $count -lt $retries ]; do
    if bundle exec rails db:migrate; then
      echo "✅ Migrations completed successfully"
      return 0

    else
      count=$((count + 1))
      if [ $count -lt $retries ]; then
        echo "⚠️ Migration failed, retrying in 5 seconds... (attempt $count/$retries)"
        sleep 5
      else
        echo "❌ Migrations failed after $retries attempts"
        return 1
      fi
    fi
  done
}

# Main execution
main() {
  # Check required environment variables
  check_required_env_vars

  # Generate SECRET_KEY_BASE if needed
  generate_secret_key_base

  # Wait for database if we're not just running a command
  if [[ "$*" == *"rails"* ]] || [[ "$*" == *"rspec"* ]] || [[ "$*" == *"bundle exec"* ]]; then
    wait_for_database
  fi

  # Run database migrations in production
  if [ "$RAILS_ENV" = "production" ]; then
    run_migrations || exit 1
  fi

  # Remove stale PID file if exists
  if [ -f tmp/pids/server.pid ]; then
    echo "🧹 Removing stale PID file..."
    rm -f tmp/pids/server.pid
  fi

  echo "🚀 Starting Rails server..."
  echo "Command: $*"

  # Execute the provided command
  exec "$@"
}

# Run main function with all arguments
main "$@"
