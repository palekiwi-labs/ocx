#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

# Nix daemon lifecycle management

use config

# Generate a short SHA hash of the Dockerfile and its dependencies
def calculate-image-hash [dockerfile_name: string] {
    let context = $env.FILE_PWD
    let dockerfile_path = ($context | path join $dockerfile_name)
    let entrypoint_path = ($context | path join "entrypoint.sh")
    
    let content = (cat $dockerfile_path $entrypoint_path)
    ($content | hash sha256 | str substring 0..7)
}

# Get the tagged daemon image name
export def get-daemon-image-name [] {
    let hash = (calculate-image-hash "Dockerfile.nix-daemon")
    $"localhost/ocx-nix-daemon:sha-($hash)"
}

# Get the tagged dev image name
export def get-dev-image-name [cfg: record] {
    let version = $cfg.opencode_version
    let hash = (calculate-image-hash "Dockerfile.nix-dev")
    $"localhost/ocx:v($version)-sha-($hash)"
}

# Generate the nix.conf content for the Daemon Container
export def generate-daemon-conf [cfg: record] {
    let user_settings = (config resolve-user $cfg)
    
    [
        "experimental-features = nix-command flakes"
        "substituters = https://cache.nixos.org"
        "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        $"trusted-users = root ($user_settings.username)"
    ] | str join "\n"
}

# Generate the nix.conf content for the Dev Container (Client)
export def generate-client-conf [cfg: record] {
    mut lines = ["experimental-features = nix-command flakes"]
    
    if not ($cfg.nix_extra_substituters | is-empty) {
        let subs = ($cfg.nix_extra_substituters | str join " ")
        $lines = ($lines | append $"extra-substituters = ($subs)")
    }
    
    if not ($cfg.nix_extra_trusted_public_keys | is-empty) {
        let keys = ($cfg.nix_extra_trusted_public_keys | str join " ")
        $lines = ($lines | append $"extra-trusted-public-keys = ($keys)")
    }
    
    $lines | str join "\n"
}

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
    let image_name = (get-daemon-image-name)
    if (not $force) and (image-exists $image_name) {
        return
    }

    print -e $"Building nix daemon image: ($image_name)"

    let context = $env.FILE_PWD
    let dockerfile = ($context | path join "Dockerfile.nix-daemon")

    mut cmd = [
        "docker" "build"
        "-f" $dockerfile
        "-t" $image_name
    ]

    if $no_cache {
        $cmd = ($cmd | append "--no-cache")
    }

    $cmd = ($cmd | append $context)

    run-external ...$cmd
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

    print -e "Initializing nix channel (nixpkgs-unstable)..."

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

    print -e "Nix channel initialized"
}

# Ensure the nix daemon container is running
export def ensure-running [cfg: record] {
    if not $cfg.nix {
        return
    }

    let container_name = (get-container-name $cfg)
    let volume_name = (get-volume-name $cfg)
    let image_name = (get-daemon-image-name)

    # Check if already running
    if (is-running $container_name) {
        return
    }

    # Ensure image exists
    if not (image-exists $image_name) {
        print -e "Nix daemon image not found, building..."
        build-nix-daemon $cfg
    }

    # Start daemon container
    print -e $"Starting nix daemon container: ($container_name)"

    let nix_conf = (generate-daemon-conf $cfg)

    let cmd = [
        "docker" "run" "-d"
        "--name" $container_name
        "--rm"
        "-e" $"NIX_CONF_CONTENT=($nix_conf)"
        "-v" $"($volume_name):/nix:rw"
        $image_name
    ]

    run-external ...$cmd

    # Give the daemon a moment to start
    sleep 1sec

    if (is-running $container_name) {
        print -e "Nix daemon started successfully"
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
        print -e $"Stopping nix daemon container: ($container_name)"
        docker stop $container_name | ignore
    } else {
        print -e "Nix daemon is not running"
    }
}

# Show status of nix daemon and volume
export def status [cfg: record] {
    let container_name = (get-container-name $cfg)
    let volume_name = (get-volume-name $cfg)
    let image_name = (get-daemon-image-name)

    print "Nix Workflow Status:"
    print $"  Enabled: ($cfg.nix)"
    print $"  Container: ($container_name)"
    print $"  Volume: ($volume_name)"
    print $"  Image: ($image_name)"
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

    print -e $"Opening shell in nix daemon container: ($container_name)"
    run-external "docker" "exec" "-it" $container_name "bash"
}

# Upgrade the nix binary/daemon itself to the latest stable version
export def upgrade [cfg: record] {
    if not $cfg.nix {
        print -e "Nix workflow is not enabled"
        print -e "Enable it by setting nix: true in your config"
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
    print -e $"Current nix version: ($current_version)"
    print -e ""

    # Update nixpkgs channel
    print -e "Updating nixpkgs channel..."
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
    print -e "Upgrading nix..."
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
    print -e "Restarting nix daemon to apply upgrade..."
    stop $cfg
    ensure-running $cfg

    # Show new version
    let new_version = (docker exec $container_name nix --version | complete | get stdout | str trim)
    print -e ""
    print -e $"Nix upgraded successfully!"
    print -e $"  Before: ($current_version)"
    print -e $"  After:  ($new_version)"
    print -e ""
    print -e "Restart your dev containers to use the updated nix version:"
    print -e "  ocx stop"
    print -e "  ocx opencode"
}

# Detect presence and paths for the user-provided custom flake
def detect-user-flake [cfg: record] {
    let user_settings = (config resolve-user $cfg)
    let host_dir = ("~/.config/ocx/nix" | path expand)
    let container_dir = $"/home/($user_settings.username)/.config/ocx/nix"
    let present = ($host_dir | path join "flake.nix" | path exists)
    { present: $present, host_dir: $host_dir, container_dir: $container_dir }
}

# Helper function to run nix flake commands within the user's flake context
def run-flake-cmd [cfg: record, subcommand: string, args: list<string>] {
    if not $cfg.nix {
        error make {
            msg: "Nix workflow is not enabled"
            label: { text: "Enable it by setting nix: true in your config" }
        }
    }

    let flake = (detect-user-flake $cfg)

    if not $flake.present {
        error make {
            msg: $"User flake not found at ($flake.host_dir)/flake.nix"
            help: "Create a flake.nix at ~/.config/ocx/nix/flake.nix to use this command"
        }
    }

    let image_name = (get-dev-image-name $cfg)

    if not (image-exists $image_name) {
        error make {
            msg: $"Nix dev image ($image_name) not found"
            label: { text: "Run 'ocx build' first to create the nix dev image" }
        }
    }

    let nix_volume = (get-volume-name $cfg)
    let nix_conf = (generate-client-conf $cfg)

    let cmd = [
        "docker" "run" "--rm"
        "-e" $"NIX_CONF_CONTENT=($nix_conf)"
        "-v" $"($nix_volume):/nix:rw"
        "-v" $"($flake.host_dir):($flake.container_dir):rw"
        "-w" $flake.container_dir
        $image_name
        "nix" "flake" $subcommand
    ] | append $args

    run-external ...$cmd
}

# Show the outputs provided by the user flake
export def "flake show" [cfg: record, ...args] {
    run-flake-cmd $cfg "show" $args
}

# Show metadata for the user flake
export def "flake metadata" [cfg: record, ...args] {
    run-flake-cmd $cfg "metadata" $args
}

# Check whether the user flake evaluates and run its tests
export def "flake check" [cfg: record, ...args] {
    run-flake-cmd $cfg "check" $args
}

# Create missing lock file entries for the user flake
export def "flake lock" [cfg: record, ...args] {
    run-flake-cmd $cfg "lock" $args
}

# Update the user flake lock file (optionally specify input names to update selectively)
export def "flake update" [cfg: record, ...args] {
    run-flake-cmd $cfg "update" $args
}
