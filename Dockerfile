# ============================================
# Stage 1: Builder
# ============================================
ARG RUBY_VERSION=3.3.0
FROM ruby:${RUBY_VERSION}-slim AS builder

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install bundler
RUN gem install bundler

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# ============================================
# Stage 2: Production
# ============================================
FROM ruby:${RUBY_VERSION}-slim AS production

# Install runtime dependencies only
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    libpq5 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash rails

WORKDIR /app

# Copy bundled gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app/vendor/bundle /app/vendor/bundle

# Copy application code
COPY --chown=rails:rails . .

# Add entrypoint script
COPY --chown=rails:rails entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set environment variables
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test"

# Switch to non-root user
USER rails

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Expose port (Render uses PORT env variable)
EXPOSE 10000

# Start Rails server on PORT (Render provides it) or default 3000
CMD bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}
