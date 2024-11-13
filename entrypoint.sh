#!/usr/bin/env bash
set -e

# Ensure /nix directory exists and has correct permissions
if [ ! -d /nix ]; then
    mkdir -p /nix
fi
chown -R root:root /nix

# Source nix profile if it exists
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi

# Initialize Nix daemon if it's not running
if ! pidof nix-daemon >/dev/null; then
    /nix/var/nix/profiles/default/bin/nix-daemon &
    sleep 1
fi

# Execute the provided command or default to bash
exec "$@"