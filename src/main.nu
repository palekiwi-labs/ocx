#!/usr/bin/env nu

# OCX - Secure Docker wrapper for OpenCode

use core/ports.nu

def main [
    --help(-h)
    --version(-v)
] {
    if $help {
        print_help
    } else if $version {
        print "TODO"
    } else {
        print_help 
    }
}

def "main run" [...args: string ] {
    print "TODO"
}

def "main build" [--force(-f)] {
    print "TODO" 
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
    
OPTIONS:
    -h, --help     Show this help
    -v, --version  Show version
    
EXAMPLES:
    ocx run                # Run OpenCode interactively
    ocx build              # Build Docker images
    ocx build --force      # Force rebuild images
    ocx version            # Show version
    ocx help               # Show help
    
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
