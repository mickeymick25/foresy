#!/bin/bash
set -e

echo "=== Foresy API Entrypoint ==="
echo "RAILS_ENV: ${RAILS_ENV:-development}"

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
