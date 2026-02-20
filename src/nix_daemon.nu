#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

# Nix daemon lifecycle management

use config

const NIX_DAEMON_IMAGE = "localhost/ocx-nix-daemon:latest"
const OCX_FLAKE = "/nix/var/ocx"

# Check if nix workflow is enabled in config
export def is-enabled [cfg: record] {
    $cfg.nix
}

# Get the nix daemon container name from config
export def get-container-name [cfg: record] {
    $cfg.nix_daemon_container_name
}

# Get the nix volume name from config
export def get-volume-name [cfg: record] {
    $cfg.nix_volume_name
}

# Check if a docker image exists
def image-exists [name: string] {
    (docker image inspect $name | complete).exit_code == 0
}

# Check if the nix daemon container is running
export def is-running [container_name: string] {
    let running = (docker ps --filter $"name=^($container_name)$"
                   --format "{{.Names}}"
                   | complete
                   | get stdout
                   | str trim)
    not ($running | is-empty)
}

# Build the nix daemon image if it doesn't exist
def build-nix-daemon [cfg: record, --force, --no-cache] {
    if (not $force) and (image-exists $NIX_DAEMON_IMAGE) {
        return
    }

    print $"Building nix daemon image: ($NIX_DAEMON_IMAGE)"

    let context = $env.FILE_PWD
    let dockerfile = ($context | path join "Dockerfile.nix-daemon")

    # Convert substituters and keys arrays to space-separated strings for build args
    let extra_substituters = ($cfg.nix_extra_substituters | str join " ")
    let extra_keys = ($cfg.nix_extra_trusted_public_keys | str join " ")

    mut cmd = [
        "docker" "build"
        "-f" $dockerfile
        "-t" $NIX_DAEMON_IMAGE
        "--build-arg" $"NIX_EXTRA_SUBSTITUTERS=($extra_substituters)"
        "--build-arg" $"NIX_EXTRA_TRUSTED_PUBLIC_KEYS=($extra_keys)"
    ]

    if $no_cache {
        $cmd = ($cmd | append "--no-cache")
    }

    $cmd = ($cmd | append $context)

    run-external ...$cmd
}

# Ensure the default flake exists in the nix volume (first-time initialization only)
export def ensure-default-flake [cfg: record] {
    if not $cfg.nix {
        return
    }

    let container_name = (get-container-name $cfg)

    # Check if daemon is running
    if not (is-running $container_name) {
        error make {
            msg: "Nix daemon is not running"
            label: {
                text: "Cannot initialize default flake without running daemon"
            }
        }
    }

    # Check if both flake.nix AND flake.lock exist
    let flake_exists = (docker exec $container_name test -f /nix/var/ocx/flake.nix | complete).exit_code == 0
    let lock_exists = (docker exec $container_name test -f /nix/var/ocx/flake.lock | complete).exit_code == 0

    if $flake_exists and $lock_exists {
        # Both files exist, fully initialized
        return
    }

    # Create directory in volume if needed
    docker exec $container_name mkdir -p /nix/var/ocx | ignore

    # Handle missing or incomplete initialization
    if $flake_exists and (not $lock_exists) {
        # flake.nix exists but lock missing - regenerate lock only
        print "Regenerating missing flake.lock..."

        let lock_result = (docker exec $container_name nix flake lock /nix/var/ocx | complete)

        if $lock_result.exit_code != 0 {
            error make {
                msg: "Failed to generate flake.lock"
                label: {
                    text: $"Error: ($lock_result.stderr)"
                }
            }
        }

        print "Default flake lock regenerated"
        print "  Lock file: /nix/var/ocx/flake.lock"
        return
    }

    # Full initialization - flake.nix doesn't exist
    print "Initializing default OCX flake in /nix/var/ocx..."

    # Load template from host
    let template_path = ($env.FILE_PWD | path join "nix/default-flake.nix")

    if not ($template_path | path exists) {
        error make {
            msg: "Default flake template not found"
            label: {
                text: $"Expected template at ($template_path)"
            }
        }
    }

    let template_content = (open $template_path)

    # Copy the flake file into the container
    echo $template_content | docker exec -i $container_name sh -c "cat > /nix/var/ocx/flake.nix"

    # Generate flake.lock in the daemon container (dev containers have read-only /nix)
    print "Generating flake.lock..."
    let lock_result = (docker exec $container_name nix flake lock /nix/var/ocx | complete)

    if $lock_result.exit_code != 0 {
        error make {
            msg: "Failed to generate flake.lock"
            label: {
                text: $"Error: ($lock_result.stderr)"
            }
        }
    }

    print "Default flake initialized successfully"
    print "  Location: /nix/var/ocx/flake.nix"
    print "  Lock file: /nix/var/ocx/flake.lock"
    print "  Update with: ocx nix update"
}

# Read the current opencode version pin from the flake inside the nix daemon container
# Returns null if nix is disabled, daemon is not running, flake is not initialized, or version cannot be parsed
export def get-opencode-version [cfg: record] {
    if not $cfg.nix {
        return null
    }

    let container_name = (get-container-name $cfg)

    if not (is-running $container_name) {
        return null
    }

    let flake_path = $"($OCX_FLAKE)/flake.nix"

    let flake_exists = (docker exec $container_name test -f $flake_path | complete).exit_code == 0
    if not $flake_exists {
        return null
    }

    let content = (docker exec $container_name cat $flake_path | complete | get stdout)

    let matches = ($content | parse --regex 'github:anomalyco/opencode/v(?P<version>[0-9]+\.[0-9]+\.[0-9]+)')

    if ($matches | is-empty) {
        return null
    }

    $matches | first | get version
}

# Update the opencode version pin in the flake inside the nix daemon container
export def update-opencode-version [cfg: record, version: string] {
    if not $cfg.nix {
        return
    }

    let container_name = (get-container-name $cfg)

    if not (is-running $container_name) {
        print "Warning: Nix daemon is not running, skipping flake pin update"
        return
    }

    let flake_path = $"($OCX_FLAKE)/flake.nix"

    let flake_exists = (docker exec $container_name test -f $flake_path | complete).exit_code == 0
    if not $flake_exists {
        print "Warning: Flake not initialized in container, skipping pin update"
        return
    }

    # Read flake out of container, replace on host, write back in
    let content = (docker exec $container_name cat $flake_path | complete | get stdout)
    let updated = ($content | str replace --regex 'github:anomalyco/opencode/[^"]+' $"github:anomalyco/opencode/v($version)")

    $updated | docker exec -i $container_name sh -c $"cat > ($flake_path)"

    print $"Updated flake opencode pin to v($version)"

    # Re-lock only the opencode input so flake.lock reflects the new tag
    print "Updating flake.lock for opencode input..."
    let lock_result = (docker exec $container_name nix flake lock --update-input opencode $OCX_FLAKE | complete)

    if $lock_result.exit_code != 0 {
        error make {
            msg: "Failed to update flake.lock"
            label: { text: $"Error: ($lock_result.stderr)" }
        }
    }

    print "Flake lock updated"
}

# Ensure the nix channel is set to nixpkgs-unstable and nix is installed from it (first-time only)
export def ensure-nix-version [cfg: record] {
    if not $cfg.nix {
        return
    }

    let container_name = (get-container-name $cfg)

    # Use a sentinel file in the volume to avoid re-running on every start
    let sentinel = "/nix/var/ocx/.nix-channel-initialized"
    let already_done = (docker exec $container_name test -f $sentinel | complete).exit_code == 0

    if $already_done {
        return
    }

    print "Initializing nix channel (nixpkgs-unstable)..."

    # Set channel explicitly to nixpkgs-unstable
    let channel_add = (docker exec $container_name nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs | complete)
    if $channel_add.exit_code != 0 {
        error make {
            msg: "Failed to set nixpkgs-unstable channel"
            label: { text: $"Error: ($channel_add.stderr)" }
        }
    }

    let channel_update = (docker exec $container_name nix-channel --update | complete)
    if $channel_update.exit_code != 0 {
        error make {
            msg: "Failed to update nix channel"
            label: { text: $"Error: ($channel_update.stderr)" }
        }
    }

    # Install nix and cacert from nixpkgs-unstable
    let install = (docker exec $container_name nix-env --install --attr nixpkgs.nix nixpkgs.cacert | complete)
    if $install.exit_code != 0 {
        error make {
            msg: "Failed to install nix from nixpkgs-unstable"
            label: { text: $"Error: ($install.stderr)" }
        }
    }

    # Write sentinel so we don't repeat this on next start
    docker exec $container_name sh -c $"mkdir -p /nix/var/ocx && touch ($sentinel)" | ignore

    print "Nix channel initialized"
}

# Ensure the nix daemon container is running
export def ensure-running [cfg: record] {
    if not $cfg.nix {
        return
    }

    let container_name = (get-container-name $cfg)
    let volume_name = (get-volume-name $cfg)

    # Check if already running
    if (is-running $container_name) {
        return
    }

    # Ensure image exists
    if not (image-exists $NIX_DAEMON_IMAGE) {
        print "Nix daemon image not found, building..."
        build-nix-daemon $cfg
    }

    # Start daemon container
    print $"Starting nix daemon container: ($container_name)"

    let cmd = [
        "docker" "run" "-d"
        "--name" $container_name
        "--rm"
        "-v" $"($volume_name):/nix:rw"
        $NIX_DAEMON_IMAGE
    ]

    run-external ...$cmd

    # Give the daemon a moment to start
    sleep 1sec

    if (is-running $container_name) {
        print "Nix daemon started successfully"
    } else {
        error make {
            msg: "Failed to start nix daemon container"
            label: {
                text: $"Container ($container_name) failed to start"
            }
        }
    }

    ensure-nix-version $cfg
}

# Stop the nix daemon container
export def stop [cfg: record] {
    let container_name = (get-container-name $cfg)

    if (is-running $container_name) {
        print $"Stopping nix daemon container: ($container_name)"
        docker stop $container_name | ignore
    } else {
        print "Nix daemon is not running"
    }
}

# Show status of nix daemon and volume
export def status [cfg: record] {
    let container_name = (get-container-name $cfg)
    let volume_name = (get-volume-name $cfg)

    print "Nix Workflow Status:"
    print $"  Enabled: ($cfg.nix)"
    print $"  Container: ($container_name)"
    print $"  Volume: ($volume_name)"
    print $"  Image: ($NIX_DAEMON_IMAGE)"
    print ""

    if (is-running $container_name) {
        print "  Status: Running ✓"
        let nix_version = (docker exec $container_name nix --version | complete | get stdout | str trim)
        print $"  Nix:    ($nix_version)"
        print ""
        print "Container stats:"
        docker stats --no-stream $container_name
    } else {
        print "  Status: Stopped"
    }

    print ""
    print "Volume info:"
    let vol_exists = (docker volume ls --filter $"name=^($volume_name)$" --format "{{.Name}}"
                      | complete
                      | get stdout
                      | str trim)

    if ($vol_exists | is-empty) {
        print $"  Volume ($volume_name) does not exist yet"
    } else {
        docker volume inspect $volume_name | from json | select Name Mountpoint Driver CreatedAt
    }
}

# Build the nix daemon image (exposed for ocx build command)
export def build [cfg: record, --force, --no-cache] {
    build-nix-daemon $cfg --force=$force --no-cache=$no_cache
}

# Open a shell in the nix daemon container
export def shell [cfg: record] {
    let container_name = (get-container-name $cfg)

    if not (is-running $container_name) {
        error make {
            msg: "Nix daemon is not running"
            label: {
                text: $"Container ($container_name) is not running. Start it with: ocx nix start"
            }
        }
    }

    print $"Opening shell in nix daemon container: ($container_name)"
    run-external "docker" "exec" "-it" $container_name "bash"
}

# Upgrade the nix binary/daemon itself to the latest stable version
export def upgrade [cfg: record] {
    if not $cfg.nix {
        print "Nix workflow is not enabled"
        print "Enable it by setting nix: true in your config"
        return
    }

    let container_name = (get-container-name $cfg)

    if not (is-running $container_name) {
        error make {
            msg: "Nix daemon is not running"
            label: {
                text: $"Container ($container_name) is not running. Start it with: ocx nix start"
            }
        }
    }

    # Show current version
    let current_version = (docker exec $container_name nix --version | complete | get stdout | str trim)
    print $"Current nix version: ($current_version)"
    print ""

    # Update nixpkgs channel
    print "Updating nixpkgs channel..."
    let channel_result = (docker exec $container_name nix-channel --update | complete)
    if $channel_result.exit_code != 0 {
        error make {
            msg: "Failed to update nix channel"
            label: {
                text: $"Error: ($channel_result.stderr)"
            }
        }
    }

    # Upgrade nix binary and cacert
    print "Upgrading nix..."
    let upgrade_result = (docker exec $container_name nix-env --install --attr nixpkgs.nix nixpkgs.cacert | complete)
    if $upgrade_result.exit_code != 0 {
        error make {
            msg: "Failed to upgrade nix"
            label: {
                text: $"Error: ($upgrade_result.stderr)"
            }
        }
    }

    # Restart daemon container to apply the new nix binary
    print "Restarting nix daemon to apply upgrade..."
    stop $cfg
    ensure-running $cfg

    # Show new version
    let new_version = (docker exec $container_name nix --version | complete | get stdout | str trim)
    print ""
    print $"Nix upgraded successfully!"
    print $"  Before: ($current_version)"
    print $"  After:  ($new_version)"
    print ""
    print "Restart your dev containers to use the updated nix version:"
    print "  ocx stop"
    print "  ocx opencode"
}

# Guard: check nix is enabled and daemon is running, return container name
def flake-guard [cfg: record] {
    if not $cfg.nix {
        error make {
            msg: "Nix workflow is not enabled"
            label: { text: "Enable it by setting nix: true in your config" }
        }
    }
    let container_name = (get-container-name $cfg)
    if not (is-running $container_name) {
        error make {
            msg: "Nix daemon is not running"
            label: { text: $"Container ($container_name) is not running. Start it with: ocx nix start" }
        }
    }
    $container_name
}

# Show the outputs provided by the OCX flake
export def "flake show" [cfg: record, ...args] {
    let c = (flake-guard $cfg)
    run-external "docker" "exec" $c "nix" "flake" "show" $OCX_FLAKE ...$args
}

# Show metadata for the OCX flake
export def "flake metadata" [cfg: record, ...args] {
    let c = (flake-guard $cfg)
    run-external "docker" "exec" $c "nix" "flake" "metadata" $OCX_FLAKE ...$args
}

# Check whether the OCX flake evaluates and run its tests
export def "flake check" [cfg: record, ...args] {
    let c = (flake-guard $cfg)
    run-external "docker" "exec" $c "nix" "flake" "check" $OCX_FLAKE ...$args
}

# Create missing lock file entries for the OCX flake
export def "flake lock" [cfg: record, ...args] {
    let c = (flake-guard $cfg)
    run-external "docker" "exec" $c "nix" "flake" "lock" $OCX_FLAKE ...$args
}

# Update the OCX flake lock file (optionally specify input names to update selectively)
export def "flake update" [cfg: record, ...args] {
    let c = (flake-guard $cfg)
    run-external "docker" "exec" $c "nix" "flake" "update" "--flake" $OCX_FLAKE ...$args
}
