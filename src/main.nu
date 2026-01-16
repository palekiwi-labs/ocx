#!/usr/bin/env nu

# OCX - Secure Docker wrapper for OpenCode

use core/docker_tools.nu
use core/ports.nu
use core/config.nu [show, show-sources]

def --wrapped "main run" [...args] {
    docker_tools run ...$args
}

def "main build" [
    --base,
    --force(-f)
] {
    docker_tools build --base=$base --force=$force
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

def print_help [] {
    print "OCX - Secure Docker wrapper for OpenCode
    
USAGE:
    ocx <SUBCOMMAND> [OPTIONS]
    
SUBCOMMANDS:
    run      Run OpenCode container
    build    Build Docker images
    config   Show configuration (use --sources to see origins)
    
OPTIONS:
    -h, --help     Show this help
    -v, --version  Show version
    
EXAMPLES:
    ocx run                  # Run OpenCode interactively
    ocx build                # Build Docker images
    ocx build --force        # Force rebuild images
    ocx config               # Show current configuration
    ocx config --sources     # Show config with sources
    ocx config --json        # Output config as JSON
    ocx config --sources --json  # Output config with sources as JSON
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
    
    See documentation for full list of configuration options.
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
