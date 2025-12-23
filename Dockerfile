# ============================================
# Stage 1: Builder
# ============================================
ARG RUBY_VERSION=3.3.0
FROM ruby:${RUBY_VERSION}-slim AS builder

# Install build dependencies including curl for health checks
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install bundler
RUN gem install bundler

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./

# Add platform to lockfile for Docker compatibility
RUN bundle lock --add-platform x86_64-linux || bundle config set --local platform x86_64-linux

# Configure bundler - flexible for all environments
RUN bundle config set --local deployment 'false'
# Don't exclude gems by default, let environment variable control this

# Install dependencies (using default path: /usr/local/bundle)
RUN bundle install --jobs 4 --retry 3

# ============================================
# Stage 2: Production
# ============================================
FROM ruby:${RUBY_VERSION}-slim AS production

# Install runtime dependencies including curl for health checks
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    libpq5 \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash rails

WORKDIR /app

# Copy bundled gems from builder (using default bundle path)
COPY --from=builder /usr/local/bundle /usr/local/bundle
RUN chown -R rails:rails /usr/local/bundle

# Copy application code
COPY --chown=rails:rails . .

# Add entrypoint script
COPY --chown=rails:rails entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set environment variables - allow override from outside
ENV RAILS_ENV=development \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_DEPLOYMENT=false

# Switch to non-root user
USER rails

# Health check for orchestration platforms (now with curl available)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Add entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Expose port (Render uses PORT env variable)
EXPOSE 3000

# Start Rails server - JSON array format for proper signal handling
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "${PORT:-3000}"]

# Add labels for better image management
LABEL maintainer="Foresy Team" \
    version="1.0" \
    description="Foresy API - Rails authentication service" \
    org.opencontainers.image.title="Foresy API" \
    org.opencontainers.image.description="Rails 7 API for authentication with JWT and OAuth"
