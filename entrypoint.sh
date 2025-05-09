#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid

# Run migrations before starting the app
bundle exec rails db:migrate

# Then exec the container’s main process (what’s set in CMD)
exec "$@"
