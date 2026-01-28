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

def --wrapped "main opencode" [...args] {
    try {
        docker_tools run ...$args
    } catch { |err|
        errors pretty-print $err
    }
}

def --wrapped "main o" [...args] {
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
    --force     # Overwrite existing files
] {
    try {
        docs --dir=$dir --version=$version --force=($force | default false)
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
        let version_path = ($env.FILE_PWD | path join "VERSION")
        if ($version_path | path exists) {
            open $version_path | str trim
        } else {
            print "unknown (VERSION file not found)"
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

def print_help [] {
    print "OCX - Secure Docker wrapper for OpenCode

USAGE:
    ocx <SUBCOMMAND> [OPTIONS]

    SUBCOMMANDS:
        opencode Run OpenCode container (alias: o)
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
        upgrade  Check for and install OpenCode updates

OPTIONS:
    -h, --help     Show this help
    -v, --version  Show version

EXAMPLES:
    ocx opencode             # Run OpenCode interactively
    ocx build                # Build Docker images
    ocx build --force        # Force rebuild images (includes base image)
    ocx build --no-cache     # Build images without cache
    ocx config               # Show current configuration
    ocx docs --dir ./docs    # Fetch documentation to ./docs
    ocx port                 # Show effective port (from config or auto-generated)
    ocx shell                # Open bash shell in running container
    ocx exec ls -la          # Execute 'ls -la' in container
    ocx stats                # Show stats for project container
    ocx stats --all          # Show stats for all OCX containers
    ocx ps                   # Show project container status
    ocx stop                 # Stop project container
    ocx image list           # List all OCX images
    ocx image list --base    # List only base images
    ocx image list --json    # List images in JSON format
    ocx image prune          # Remove old images, keep latest version
    ocx image prune --base   # Prune only base images
    ocx image remove-all     # Remove all OCX images
    ocx upgrade              # Check and update to latest version
    ocx version              # Show version
    ocx help                 # Show help

ENVIRONMENT VARIABLES:
    OCX_ADD_HOST_DOCKER_INTERNAL Enable host.docker.internal host (true/false, default: true)
    OCX_CONTAINER_NAME           Override container name
    OCX_CPUS                     CPU limit (default: 1.0)
    OCX_CUSTOM_BASE_DOCKERFILE   Path to custom base Dockerfile
    OCX_ENV_FILE                 Project env file name (default: ocx.env)
    OCX_FORBIDDEN                Colon-separated paths to block
    OCX_MEMORY                   Memory limit (default: 1024m)
    OCX_NETWORK                  Docker network mode (default: bridge)
    OCX_OPENCODE_CONFIG_DIR      OpenCode config directory path
    OCX_OPENCODE_VERSION         OpenCode version (default: latest)
    OCX_PIDS_LIMIT               Process limit (default: 100)
    OCX_PORT                     Override port number
    OCX_PUBLISH_PORT             Enable/disable port publishing (true/false)
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
            let version_path = ($env.FILE_PWD | path join "VERSION")
            if ($version_path | path exists) {
                open $version_path | str trim
            } else {
                # Fallback if running directly without proper install structure
                # and not in source root
                print "unknown (VERSION file not found)"
            }
        } else {
            print_help
        }
    } catch { |err|
        errors pretty-print $err
    }
}
