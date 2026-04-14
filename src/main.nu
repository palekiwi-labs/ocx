#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

# OCX - Secure Docker wrapper for OpenCode

use docker_tools
use ports.nu
use config [load, show, show-sources]
use upgrade.nu
use errors.nu
use docs.nu
use nix_daemon.nu

def --wrapped "main opencode" [...args] {
    try {
        docker_tools opencode ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main o" [...args] {
    try {
        docker_tools opencode ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main run" [...args] {
    try {
        docker_tools run ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def "main build" [
    --base,
    --force(-f),
    --no-cache
] {
    try {
        docker_tools build --base=$base --force=$force --no-cache=$no_cache
    } catch { |err|
        errors pretty-print $err
    }
}

def "main config" [
    --sources  # Show configuration with sources
    --json     # Output as JSON only
] {
    try {
        if $sources {
            show-sources --json=$json
        } else {
            show --json=$json
        }
    } catch { |err|
        errors pretty-print $err
    }
}

def "main docs" [
    --dir: path,      # Output directory (base)
    --version: string, # Optional version override
    --force,           # Overwrite existing files
    --skill,           # Create agent skill instead of regular docs
    --global,          # Create skill in global config (~/.config/opencode)
    --project,         # Create skill in project config (./.opencode)
    --ocx,             # Download OCX documentation instead of OpenCode
] {
    try {
        docs --dir=$dir --version=$version --force=$force --skill=$skill --global=$global --project=$project --ocx=$ocx
    } catch { |err|
        errors pretty-print $err
    }
}

def "main port" [] {
    try {
        let cfg = load
        if $cfg.port == null {
            ports generate
        } else {
            $cfg.port
        }
    } catch { |err|
        errors pretty-print $err
    }
}

def "main shell" [] {
    try {
        docker_tools shell
    } catch { |err|
        errors pretty-print $err
    }
}

def "main stats" [
    --all
] {
    try {
        docker_tools stats --all=$all
    } catch { |err|
        errors pretty-print $err
    }
}

def "main ps" [
    --all(-a)
] {
    try {
        docker_tools ps --all=$all
    } catch { |err|
        errors pretty-print $err
    }
}

def "main volume" [] {
    try {
        docker_tools volume
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main exec" [...args] {
    try {
        docker_tools exec ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def "main stop" [] {
    try {
        docker_tools stop
    } catch { |err|
        errors pretty-print $err
    }
}

def "main upgrade" [--check] {
    try {
        upgrade --check=$check
    } catch { |err|
        errors pretty-print $err
    }
}

def "main version" [] {
    try {
                let version_path = ($env.FILE_PWD | path join "VERSION.txt")
        if ($version_path | path exists) {
            open $version_path | str trim
        } else {
                        print -e "unknown (VERSION.txt file not found)"
        }
    } catch { |err|
        errors pretty-print $err
    }
}

def "main help" [] {
    try {
        print_help
    } catch { |err|
        errors pretty-print $err
    }
}

def "main image" [] {
    try {
        docker_tools image
    } catch { |err|
        errors pretty-print $err
    }
}

def "main image list" [
    --base     # Show only base images
    --final    # Show only final OCX images
    --json     # Output as JSON
] {
    try {
        docker_tools image list --base=$base --final=$final --json=$json
    } catch { |err|
        errors pretty-print $err
    }
}

def "main image prune" [
    --base     # Prune only base images
    --final    # Prune only final OCX images
] {
    try {
        docker_tools image prune --base=$base --final=$final
    } catch { |err|
        errors pretty-print $err
    }
}

def "main image remove-all" [
    --base     # Remove only base images
    --final    # Remove only final OCX images
] {
    try {
        docker_tools image remove-all --base=$base --final=$final
    } catch { |err|
        errors pretty-print $err
    }
}

def "main nix" [] {
        print "OCX Nix Management

USAGE:
    ocx nix <SUBCOMMAND>

SUBCOMMANDS:
    status          Show nix daemon status
    start           Start nix daemon container
    stop            Stop nix daemon container
    restart         Restart nix daemon container
    shell           Open shell in nix daemon container
    flake           Manage your custom flake (~/.config/ocx/nix/flake.nix)
    upgrade         Upgrade nix binary/daemon to latest stable version

EXAMPLES:
    ocx nix status           # Check if nix daemon is running
    ocx nix start            # Manually start nix daemon
    ocx nix stop             # Stop nix daemon
    ocx nix restart          # Restart nix daemon
    ocx nix shell            # Open shell for inspection
    ocx nix flake            # Show flake subcommands
    ocx nix upgrade          # Upgrade nix binary to latest stable version
"
}

def "main nix flake" [] {
    print "OCX Nix Flake

Manage your custom flake at ~/.config/ocx/nix/flake.nix.
All commands require a flake.nix at that location.

USAGE:
    ocx nix flake <SUBCOMMAND>

SUBCOMMANDS:
    init        Scaffold a basic flake.nix if not present
    show        Show the outputs provided by your custom flake
    metadata    Show flake metadata
    check       Check whether the flake evaluates and run its tests
    lock        Create missing lock file entries
    update      Update flake lock file (writes flake.lock back to host)

EXAMPLES:
    ocx nix flake init                 # Scaffold initial flake.nix
    ocx nix flake show                 # Show flake outputs
    ocx nix flake show --json          # Show flake outputs as JSON
    ocx nix flake metadata             # Show flake metadata
    ocx nix flake check                # Evaluate and run checks
    ocx nix flake check --no-build     # Evaluate without building
    ocx nix flake lock                 # Create missing lock entries
    ocx nix flake update               # Update all inputs
    ocx nix flake update nixpkgs       # Update a single input
"
}

def "main nix status" [] {
    try {
        let cfg = load
        nix_daemon status $cfg
    } catch { |err|
        errors pretty-print $err
    }
}

def "main nix start" [] {
    try {
        let cfg = load
        nix_daemon ensure-running $cfg
    } catch { |err|
        errors pretty-print $err
    }
}

def "main nix stop" [] {
    try {
        let cfg = load
        nix_daemon stop $cfg
    } catch { |err|
        errors pretty-print $err
    }
}

def "main nix restart" [] {
    try {
        let cfg = load
        nix_daemon stop $cfg
        nix_daemon ensure-running $cfg
    } catch { |err|
        errors pretty-print $err
    }
}

def "main nix shell" [] {
    try {
        let cfg = load
        nix_daemon shell $cfg
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main nix flake show" [...args] {
    try {
        let cfg = load
        nix_daemon flake show $cfg ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main nix flake metadata" [...args] {
    try {
        let cfg = load
        nix_daemon flake metadata $cfg ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main nix flake check" [...args] {
    try {
        let cfg = load
        nix_daemon flake check $cfg ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main nix flake lock" [...args] {
    try {
        let cfg = load
        nix_daemon flake lock $cfg ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main nix flake update" [...args] {
    try {
        let cfg = load
        nix_daemon flake update $cfg ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def "main nix flake init" [--force] {
    try {
        let cfg = load
        nix_daemon flake init $cfg --force=$force
    } catch { |err|
        errors pretty-print $err
    }
}

def "main nix upgrade" [] {
    try {
        let cfg = load
        nix_daemon upgrade $cfg
    } catch { |err|
        errors pretty-print $err
    }
}

def print_help [] {
    print "OCX - Secure Docker wrapper for OpenCode

USAGE:
    ocx <SUBCOMMAND> [OPTIONS]

    SUBCOMMANDS:
        opencode Run OpenCode container (alias: o)
        run      Run a task headlessly via opencode run
        build    Build Docker images
        config   Show configuration (use --sources to see origins)
        docs     Fetch and save OpenCode documentation
        port     Show the port number that will be used for the container
        shell    Open shell in running container
        exec     Execute command in running container
        stats    Show container stats
        ps       List running containers
        stop     Stop project container
        volume   List project volumes
        image    Manage OCX Docker images
        nix      Manage nix daemon container
        upgrade  Check for and install OpenCode update

OPTIONS:
    -h, --help     Show this help
    -v, --version  Show version

    EXAMPLES:
    ocx opencode                    # Run OpenCode interactively
    ocx run summarize -f src/main.nu    # Run a task headlessly
    ocx run --agent explore             # Run with a specific agent
    ocx build                       # Build Docker images
    ocx build --force               # Force rebuild images (includes base image)
    ocx build --no-cache            # Build images without cache
    ocx config                      # Show current configuration
    ocx docs --dir ./docs           # Fetch OpenCode documentation to ./docs
    ocx docs --ocx --dir ./docs     # Fetch OCX documentation to ./docs
    ocx docs --skill                # Create opencode documentation skill (global)
    ocx docs --skill --project      # Create opencode documentation skill (project)
    ocx docs --ocx --skill          # Create OCX documentation skill (global)
    ocx docs --ocx --skill --project # Create OCX documentation skill (project)
    ocx port                        # Show effective port (from config or auto-generated)
    ocx shell                       # Open bash shell in running container
    ocx exec ls -la                 # Execute 'ls -la' in container
    ocx stats                       # Show stats for project container
    ocx stats --all                 # Show stats for all OCX containers
    ocx ps                          # Show project container status
    ocx stop                        # Stop project container
    ocx image list                  # List all OCX images
    ocx image list --base           # List only base images
    ocx image list --json           # List images in JSON format
    ocx image prune                 # Remove old images, keep latest version
    ocx image prune --base          # Prune only base images
    ocx image remove-all            # Remove all OCX images
    ocx nix status                  # Show nix daemon status
    ocx nix start                   # Start nix daemon
    ocx nix stop                    # Stop nix daemon
    ocx nix shell                   # Open shell in nix daemon
    ocx nix flake init              # Scaffold your custom flake
    ocx nix flake update            # Update your custom flake
    ocx nix upgrade                 # Upgrade nix binary/daemon
    ocx upgrade                     # Check and update to latest version
    ocx version                     # Show version
    ocx help                        # Show help

ENVIRONMENT VARIABLES:
    OCX_ADD_HOST_DOCKER_INTERNAL Enable host.docker.internal host (true/false, default: true)
    OCX_CONTAINER_NAME           Override container name
    OCX_CPUS                     CPU limit (default: 1.0)
    OCX_CUSTOM_BASE_DOCKERFILE   Path to custom base Dockerfile
    OCX_DATA_VOLUMES_MODE        Volume mode (git, always, never)
    OCX_DATA_VOLUMES_NAME        Override volume name
    OCX_ENV_FILE                 Project env file name (default: ocx.env)
    OCX_EXTRA_DATA_VOLUMES       JSON string for extra volumes
    OCX_FORBIDDEN                Colon-separated paths to block
    OCX_MEMORY                   Memory limit (default: 1024m)
    OCX_NETWORK                  Docker network mode (default: bridge)
    OCX_NIX_DAEMON_CONTAINER_NAME Nix daemon container name (default: ocx-nix-daemon)
    OCX_NIX                      Enable nix workflow (true/false, default: false)
    OCX_NIX_VOLUME_NAME          Nix volume name (default: ocx-nix)
    OCX_OPENCODE_CONFIG_DIR      OpenCode config directory path
    OCX_OPENCODE_VERSION         OpenCode version (default: latest)
    OCX_PIDS_LIMIT               Process limit (default: 100)
    OCX_PORT                     Override port number
    OCX_PUBLISH_PORT             Enable/disable port publishing (true/false)
    OCX_VERSION_CACHE_TTL_HOURS  Version check cache TTL in hours (default: 24)
    OCX_WORKSPACE                Workspace directory path (default: current directory)

    See documentation for full list of configuration options.

CONFIGURATION FILES:
    Global:  ~/.config/ocx/ocx.json
    Project: ./ocx.json

    Config priority: env vars > project > global > defaults

CUSTOM BASE IMAGES:
    Provide a Dockerfile to customize the base environment.
    Place in global config or project directory:

    Global:  ~/.config/ocx/ruby/Dockerfile  → ocx-ruby:1.1.23
    Project: ./docker-ocx/Dockerfile        → ocx-<projectname>-docker-ocx:1.1.23

    Config: {\"custom_base_dockerfile\": \"ruby/Dockerfile\"}

    See docs/custom-base-template.md for Dockerfile requirements.
 "
}

# Override built-in help to show custom help for main script
# This intercepts the --help flag before Nushell's auto-generated help
def help [...rest] {
    print_help
}

def main [--version(-v)] {
    try {
        if $version {
                    let version_path = ($env.FILE_PWD | path join "VERSION.txt")
            if ($version_path | path exists) {
                open $version_path | str trim
            } else {
                # Fallback if running directly without proper install structure
                # and not in source root
                            print -e "unknown (VERSION.txt file not found)"
            }
        } else {
            print_help
        }
    } catch { |err|
        errors pretty-print $err
    }
}
