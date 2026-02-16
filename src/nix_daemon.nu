#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

# Nix daemon lifecycle management

use config

const NIX_DAEMON_IMAGE = "localhost/ocx-nix-daemon:latest"

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

# Update the default flake (checks for template updates, then updates flake.lock)
export def update [cfg: record] {
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

    # Check if default flake exists
    let flake_exists = (docker exec $container_name test -f /nix/var/ocx/flake.nix | complete).exit_code == 0

    if not $flake_exists {
        error make {
            msg: "Default flake not found"
            label: {
                text: "Run 'ocx opencode' first to initialize the default flake"
            }
        }
    }

    # Check for template updates
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
    let template_hash = ($template_content | hash md5)
    let existing_content = (docker exec $container_name cat /nix/var/ocx/flake.nix | complete | get stdout)
    let existing_hash = ($existing_content | hash md5)

    if $template_hash != $existing_hash {
        # Template changed - backup and update
        print "Newer default flake template detected, updating..."
        docker exec $container_name cp /nix/var/ocx/flake.nix /nix/var/ocx/flake.nix.backup | ignore
        print "  Previous flake backed up to: /nix/var/ocx/flake.nix.backup"

        # Apply new template atomically
        echo $template_content | docker exec -i $container_name sh -c "cat > /nix/var/ocx/flake.nix.tmp && mv /nix/var/ocx/flake.nix.tmp /nix/var/ocx/flake.nix"
        print "  Template updated"
        print ""
    }

    # Update flake.lock
    print "Updating flake.lock..."
    print "  Running: nix flake update /nix/var/ocx"

    # Run nix flake update in the daemon container
    let result = (docker exec $container_name nix flake update --flake /nix/var/ocx | complete)

    if $result.exit_code != 0 {
        error make {
            msg: "Failed to update flake"
            label: {
                text: $"Error: ($result.stderr)"
            }
        }
    }

    print ""
    print "Flake updated successfully!"
    print "Restart your dev containers to use the updated packages:"
    print "  ocx stop"
    print "  ocx opencode"
}
