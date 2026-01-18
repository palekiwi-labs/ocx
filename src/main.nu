#!/usr/bin/env nu

# OCX - Secure Docker wrapper for OpenCode

use docker_tools
use ports.nu
use config [show, show-sources]
use upgrade.nu

def --wrapped "main run" [...args] {
    docker_tools run ...$args
}

def "main build" [
    --base,
    --force(-f)
    --force-overlay
] {
    docker_tools build --base=$base --force=$force --force-overlay=$force_overlay
}

def "main config" [
    --sources
    --json
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

def "main upgrade" [--check] {
    upgrade --check=$check
}

def print_help [] {
    print "OCX - Secure Docker wrapper for OpenCode
    
USAGE:
    ocx <SUBCOMMAND> [OPTIONS]
    
    SUBCOMMANDS:
        run      Run OpenCode container
        build    Build Docker images
        config   Show configuration (use --sources to see origins)
        shell    Open shell in running container
        upgrade   Check for and install OpenCode updates
    
    BUILD OPTIONS:
        --base            Build base image only
        --force, -f       Force rebuild all images (no cache)
        --force-overlay   Force rebuild overlay only
    
    OPTIONS:
        -h, --help     Show this help
        -v, --version  Show version
    
    EXAMPLES:
        # Run OpenCode
        ocx run
        
        # Build images
        ocx build                  # Build OCX + overlay (if configured)
        ocx build --force          # Force rebuild all images
        ocx build --force-overlay  # Rebuild overlay only (fast)
        
        # Configuration
        ocx config               # Show current configuration
        ocx config --sources     # Show config with sources
        ocx config --json        # Output config as JSON
        ocx config --sources --json  # Output config with sources as JSON
        
        # Other
        ocx shell                # Open bash shell in running container
        ocx upgrade              # Check and update to latest version
        ocx upgrade --check      # Only check, don't install
        ocx version              # Show version
        ocx help                 # Show help
    
    OVERLAYS:
        Extend OCX with project-specific or reusable environments.
        
        Config options:
        - overlay_dockerfile    Path to Dockerfile (relative)
        - overlay_image_name    Image name suffix (defaults to project name)
        
        Example project config (./ocx.json):
        {
          \"overlay_dockerfile\": \"./Dockerfile.ocx\",
          \"overlay_image_name\": \"my-rails-app\"
        }
        
        Example global config (~/.config/ocx/ocx.json):
        {
          \"overlay_dockerfile\": \"ruby/Dockerfile\",
          \"overlay_image_name\": \"ruby\"
        }
        
        Dockerfile pattern:
        ARG BASE_IMAGE
        FROM \${BASE_IMAGE}
        # Your customizations...
        CMD [\"opencode\"]
        
        Build args provided: BASE_IMAGE, OCX_VERSION, USERNAME
    
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
        OCX_OPENCODE_VERSION   OpenCode version (default: latest)
        OCX_OVERLAY_DOCKERFILE Overlay Dockerfile path
        OCX_OVERLAY_IMAGE_NAME Overlay image name
        
        See documentation for full list of configuration options.

    CONFIGURATION FILES:
        Global:  ~/.config/ocx/ocx.json
        Project: ./ocx.json
        
        Config priority: env vars > project > global > defaults
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
