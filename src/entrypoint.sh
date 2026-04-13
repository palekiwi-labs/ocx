#!/usr/bin/env sh
set -eu

# If NIX_CONF_CONTENT is provided, write it to /etc/nix/nix.conf
if [ -n "${NIX_CONF_CONTENT:-}" ]; then
    # Check if running as root
    if [ "$(id -u)" = "0" ]; then
        mkdir -p /etc/nix
        # Remove existing nix.conf (which might be a read-only symlink in NixOS images)
        # before writing the new content as a regular file.
        rm -f /etc/nix/nix.conf
        echo "$NIX_CONF_CONTENT" > /etc/nix/nix.conf
        # Ensure it's readable but secure
        chmod 644 /etc/nix/nix.conf
    else
        # Running as non-root dev user
        mkdir -p "$HOME/.config/nix"
        echo "$NIX_CONF_CONTENT" > "$HOME/.config/nix/nix.conf"
        chmod 644 "$HOME/.config/nix/nix.conf"
    fi
fi

exec "$@"
