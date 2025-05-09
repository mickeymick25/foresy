# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.0
FROM ruby:${RUBY_VERSION}

# Install OS dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs postgresql-client

# Set working directory
WORKDIR /app

# Install bundler
RUN gem install bundler

# Copy Gemfile and install dependencies
COPY Gemfile* ./
RUN bundle install

# Copy application code
COPY . .

# Precompile assets for production
RUN if [ "$RAILS_ENV" = "production" ]; then bundle exec rake assets:precompile; fi

# Add entrypoint
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Expose Render port
EXPOSE 10000

# Use PORT from env (Render provides it), fallback to 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "${PORT:-3000}"]
