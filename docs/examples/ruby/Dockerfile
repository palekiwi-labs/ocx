FROM ruby:3.4-slim

# Install system packages
# NOTE: curl is REQUIRED for OCX to download OpenCode binary
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    postgresql-client \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
COPY Gemfile* ./
RUN bundle install

WORKDIR /workspace
