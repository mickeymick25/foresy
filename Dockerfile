# ============================================
# Foresy API - Gold Level Dockerfile
# Ruby 3.4.8 + Rails 8.1.1
# Optimized for performance, security & quality
# ============================================

# Global ARGs
ARG RUBY_VERSION=3.4.8
ARG BUNDLER_VERSION=2.6.2

# ============================================
# Stage 1: Base (common dependencies)
# ============================================
FROM ruby:${RUBY_VERSION}-slim AS base

ARG BUNDLER_VERSION

# Set environment
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Install runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install bundler
RUN gem install bundler:${BUNDLER_VERSION} --no-document

WORKDIR /app

# ============================================
# Stage 2: Builder (compile gems)
# ============================================
FROM base AS builder

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev \
    git \
    pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy dependency files
COPY Gemfile Gemfile.lock ./

# Configure bundler for ALL gems (dev + test + production)
RUN bundle config set --local path vendor/bundle && \
    bundle config set --local jobs 4 && \
    bundle config set --local retry 3

# Install ALL dependencies (including dev/test for builder stage)
RUN bundle install && \
    rm -rf vendor/bundle/ruby/*/cache/*.gem && \
    find vendor/bundle/ruby/*/gems/ -name "*.c" -delete && \
    find vendor/bundle/ruby/*/gems/ -name "*.o" -delete

# Copy application code
COPY . .

# ============================================
# Stage 3: Development (for docker-compose)
# ============================================
FROM builder AS development

# Create non-root user
RUN useradd --create-home --shell /bin/bash rails && \
    mkdir -p tmp/pids tmp/cache log && \
    chown -R rails:rails /app

# Development environment
ENV RAILS_ENV=development \
    RAILS_LOG_TO_STDOUT=true \
    BUNDLE_PATH=/app/vendor/bundle \
    RUBY_YJIT_ENABLE=1 \
    MALLOC_ARENA_MAX=2

# Expose port
EXPOSE 3000

# Default command for development
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]

# ============================================
# Stage 4: Production Builder (slim gems)
# ============================================
FROM base AS production-builder

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev \
    git \
    pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy dependency files
COPY Gemfile Gemfile.lock ./

# Configure bundler for production (exclude dev/test gems)
RUN bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle config set --local path vendor/bundle && \
    bundle config set --local jobs 4 && \
    bundle config set --local retry 3

# Install production dependencies only
RUN bundle install && \
    rm -rf vendor/bundle/ruby/*/cache/*.gem && \
    find vendor/bundle/ruby/*/gems/ -name "*.c" -delete && \
    find vendor/bundle/ruby/*/gems/ -name "*.o" -delete && \
    find vendor/bundle/ruby/*/gems/ -name "*.h" -delete && \
    find vendor/bundle/ruby/*/gems/ -name "*.hpp" -delete && \
    find vendor/bundle/ruby/*/gems/ -name "*.java" -delete

# ============================================
# Stage 5: Production (final slim image)
# ============================================
FROM base AS production

# Metadata labels (OCI standard)
LABEL org.opencontainers.image.title="Foresy API" \
    org.opencontainers.image.description="Rails 8.1.1 API for authentication with JWT and OAuth" \
    org.opencontainers.image.version="2.0.0" \
    org.opencontainers.image.vendor="Foresy Team" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.source="https://github.com/foresy/foresy-api"

# Create non-root user and directories
RUN useradd --create-home --shell /bin/bash rails && \
    mkdir -p /app/tmp/pids /app/tmp/cache /app/log && \
    chown -R rails:rails /app

WORKDIR /app

# Copy bundled gems from production-builder
COPY --from=production-builder --chown=rails:rails /app/vendor/bundle /app/vendor/bundle

# Configure bundler
RUN bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle config set --local path vendor/bundle

# Copy application code
COPY --chown=rails:rails . .

# Ensure entrypoint is executable
RUN chmod +x /app/entrypoint.sh

# Production environment variables
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    RUBY_YJIT_ENABLE=1 \
    MALLOC_ARENA_MAX=2 \
    BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=true

# Switch to non-root user
USER rails

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:${PORT:-3000}/health || exit 1

# Expose port
EXPOSE 3000

# Entrypoint for initialization
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command (JSON format for proper signal handling)
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
