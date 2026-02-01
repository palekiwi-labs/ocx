FROM rust:latest

# Install essential tools for development
# NOTE: rust:latest includes: curl, git, ca-certificates, gnupg, build-essential
RUN apt-get update && apt-get install -y --no-install-recommends \
    fd-find \
    jq \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*
