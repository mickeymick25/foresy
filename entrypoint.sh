#!/bin/bash
set -e

echo "=== Foresy API Entrypoint ==="
echo "RAILS_ENV: ${RAILS_ENV:-development}"

# Wait for database to be ready
if [ -n "$DATABASE_URL" ]; then
  echo "Waiting for database to be ready..."

  # Extract host and port from DATABASE_URL
  DB_HOST=$(echo "$DATABASE_URL" | sed -E 's/.*@([^:\/]+).*/\1/')
  DB_PORT=$(echo "$DATABASE_URL" | sed -E 's/.*:([0-9]+)\/.*/\1/')
  DB_PORT=${DB_PORT:-5432}

  # Wait for PostgreSQL
  MAX_RETRIES=30
  RETRY_COUNT=0

  until pg_isready -h "$DB_HOST" -p "$DB_PORT" -q 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
      echo "ERROR: Database not ready after $MAX_RETRIES attempts"
      exit 1
    fi
    echo "Waiting for database... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
  done

  echo "✅ Database is ready"
fi

# Run database migrations in production
if [ "$RAILS_ENV" = "production" ]; then
  echo "Running database migrations..."
  bundle exec rails db:migrate
  echo "✅ Migrations completed"
fi

# Remove stale PID file if exists
if [ -f tmp/pids/server.pid ]; then
  echo "Removing stale PID file..."
  rm -f tmp/pids/server.pid
fi

echo "=== Starting Rails server ==="

# Execute CMD from Dockerfile
exec "$@"
