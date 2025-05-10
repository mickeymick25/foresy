#!/bin/bash
set -e

# Wait for DB to be ready (optional but useful for Docker Compose/local dev)
if [ -n "$DATABASE_URL" ]; then
  echo "Waiting for database to be ready..."
  until pg_isready -q -d "$DATABASE_URL"; do
    sleep 1
  done
fi

# Run database migrations if needed (optional in prod)
if [ "$RAILS_ENV" = "production" ]; then
  echo "Running migrations..."
  bundle exec rails db:migrate
fi

# Execute CMD from Dockerfile (i.e. Rails server)
exec "$@"
