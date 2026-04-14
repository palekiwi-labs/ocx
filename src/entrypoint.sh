#!/usr/bin/env sh
set -eu

# If NIX_CONF_CONTENT is provided, write it to the appropriate config location
if [ -n "${NIX_CONF_CONTENT:-}" ]; then
    # Only handle dynamic configuration for the root user (nix-daemon container)
    if [ "$(id -u)" = "0" ]; then
        mkdir -p /etc/nix
        # Remove existing nix.conf (which might be a read-only symlink in NixOS images)
        # before writing the new content as a regular file.
        rm -f /etc/nix/nix.conf
        printf '%s\n' "$NIX_CONF_CONTENT" > /etc/nix/nix.conf
        # Ensure it's readable but secure
        chmod 644 /etc/nix/nix.conf
    fi
fi

exec "$@"

