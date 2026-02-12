FROM ubuntu:22.04

# Install Nix dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Note: Nix itself is installed on host
# Container will access /nix/store via read-only bind mount
