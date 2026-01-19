#!/usr/bin/env nu

# OCX - Secure Docker wrapper for OpenCode

use docker_tools
use ports.nu
use config [show, show-sources]
use upgrade.nu

def --wrapped "main opencode" [...args] {
    docker_tools run ...$args
}

def "main build" [
    --base,
    --force(-f),
    --no-cache
] {
    docker_tools build --base=$base --force=$force --no-cache=$no_cache
}

def "main config" [
    --sources  # Show configuration with sources
    --json     # Output as JSON only
] {
    if $sources {
        show-sources --json=$json
    } else {
        show --json=$json
    }
}

def "main port generate" [] {
    ports generate
} 

def "main shell" [] {
    docker_tools shell
}

def "main stats" [
    --all
] {
    docker_tools stats --all=$all
}

def "main ps" [
    --all(-a)
] {
    docker_tools ps --all=$all
}

def "main volume" [] {
    docker_tools volume
}

def --wrapped "main exec" [...args] {
    docker_tools exec ...$args
}

def "main stop" [] {
    docker_tools stop
}

def "main upgrade" [--check] {
    upgrade --check=$check
}

def print_help [] {
    print "OCX - Secure Docker wrapper for OpenCode
    
USAGE:
    ocx <SUBCOMMAND> [OPTIONS]
    
    SUBCOMMANDS:
        opencode Run OpenCode container
        build    Build Docker images
        config   Show configuration (use --sources to see origins)
        shell    Open shell in running container
        exec     Execute command in running container
        stats    Show container stats
        ps       List running containers
        stop     Stop project container
        volume   List project volumes
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
    ocx shell                # Open bash shell in running container
    ocx exec ls -la          # Execute 'ls -la' in container
    ocx stats                # Show stats for project container
    ocx stats --all          # Show stats for all OCX containers
    ocx ps                   # Show project container status
    ocx stop                 # Stop project container
    ocx upgrade              # Check and update to latest version
    ocx version              # Show version
    ocx help                 # Show help
    
ENVIRONMENT VARIABLES:
    OCX_WORKSPACE          Workspace directory path
    OCX_CONTAINER_NAME     Override container name
    OCX_PORT               Override port number
    OCX_CONFIG_DIR         Config directory path
    OCX_PUBLISH_PORT       Enable/disable port publishing (true/false)
    OCX_FORBIDDEN          Colon-separated paths to block
    OCX_NETWORK            Docker network mode (default: bridge)
    OCX_MEMORY             Memory limit (default: 1024m)
    OCX_CPUS               CPU limit (default: 1.0)
    OCX_PIDS_LIMIT         Process limit (default: 100)
    OCX_OPENCODE_VERSION       OpenCode version (default: latest)
    OCX_CUSTOM_BASE_DOCKERFILE Path to custom base Dockerfile
    OCX_ENV_FILE               Project env file name (default: ocx.env)
    
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

def main [
    --version(-v)
] {
    if $version {
        print "TODO"
    } else {
        print_help 
    }
}
