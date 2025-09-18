# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.3.7
FROM ruby:${RUBY_VERSION}-slim AS base

ENV BUNDLE_WITHOUT="development:test"
ENV RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    RACK_ENV=production \
    RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    APP_HOME=/app

# Optional: install Chromium for headless browser scraping
ARG INSTALL_CHROMIUM=false

WORKDIR ${APP_HOME}

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    ca-certificates \
    pkg-config \
    libpq-dev \
    libyaml-dev \
    libglib2.0-0 \
    libglib2.0-dev \
    libvips \
    libvips-dev \
    libheif-dev \
    libpoppler-glib8 \
    procps \
    shared-mime-info \
    ffmpeg \
    tzdata \
 && if [ "$INSTALL_CHROMIUM" = "true" ]; then \
      apt-get install -y --no-install-recommends chromium; \
    fi \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install gems first (leverage layer caching)
COPY Gemfile Gemfile.lock ./
RUN gem update --system && \
    gem install bundler -v 2.4.14 && \
    bundle install --jobs=4 --retry=3

# Copy application code
COPY . .

# Ensure entrypoint is executable
RUN chmod +x bin/docker-entrypoint

# Skip asset precompilation at build time
# Rails will compile assets on demand with config.assets.compile = true

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]


