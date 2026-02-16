#!/usr/bin/env nu
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Palekiwi Labs

# Nix daemon lifecycle management

use config

const NIX_DAEMON_IMAGE = "localhost/ocx-nix-daemon:latest"

# Check if nix workflow is enabled in config
export def is-enabled [] {
    let cfg = (config load)
    $cfg.nix_enabled
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
def build-nix-daemon [--force, --no-cache] {
    if (not $force) and (image-exists $NIX_DAEMON_IMAGE) {
        return
    }
    
    print $"Building nix daemon image: ($NIX_DAEMON_IMAGE)"
    
    let context = $env.FILE_PWD
    let dockerfile = ($context | path join "Dockerfile.nix-daemon")
    
    mut cmd = [
        "docker" "build"
        "-f" $dockerfile
        "-t" $NIX_DAEMON_IMAGE
    ]
    
    if $no_cache {
        $cmd = ($cmd | append "--no-cache")
    }
    
    $cmd = ($cmd | append $context)
    
    run-external ...$cmd
}

# Ensure the nix daemon container is running
export def ensure-running [] {
    let cfg = (config load)
    
    if not $cfg.nix_enabled {
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
        build-nix-daemon
    }
    
    # Start daemon container
    print $"Starting nix daemon container: ($container_name)"
    
    docker run -d \
        --name $container_name \
        --rm \
        -v $"($volume_name):/nix:rw" \
        $NIX_DAEMON_IMAGE
    
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
export def stop [] {
    let cfg = (config load)
    let container_name = (get-container-name $cfg)
    
    if (is-running $container_name) {
        print $"Stopping nix daemon container: ($container_name)"
        docker stop $container_name | ignore
    } else {
        print "Nix daemon is not running"
    }
}

# Show status of nix daemon and volume
export def status [] {
    let cfg = (config load)
    let container_name = (get-container-name $cfg)
    let volume_name = (get-volume-name $cfg)
    
    print "Nix Workflow Status:"
    print $"  Enabled: ($cfg.nix_enabled)"
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
        docker volume inspect $volume_name | from json | select -i Name Mountpoint Driver CreatedAt
    }
}

# Build the nix daemon image (exposed for ocx build command)
export def build [--force, --no-cache] {
    build-nix-daemon --force=$force --no-cache=$no_cache
}
