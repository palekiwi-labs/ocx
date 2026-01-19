use ../config
use ../ports.nu

export def image_exists [name: string] {
    (docker image inspect $name | complete).exit_code == 0
}

export def resolve-container-name [port: int] {
    let cfg = (config load)
    
    if $cfg.container_name != null {
        $"($cfg.container_name)-($port)"
    } else {
        let base = ($env.PWD | path basename)
        $"ocx-($base)-($port)"
    }
}

export def get-current-container-name [] {
    let cfg = (config load)
    let port = if $cfg.port == null { ports generate } else { $cfg.port }
    resolve-container-name $port
}

export def container-is-running [container_name: string] {
    let running = (docker ps --filter $"name=^($container_name)$" --format "{{.Names}}" 
                   | complete 
                   | get stdout 
                   | str trim)
    
    not ($running | is-empty)
}

export def resolve-dockerfile-path [dockerfile_path: string] {
    # Check project-local first
    let project_path = ($dockerfile_path | path expand)
    if ($project_path | path exists) {
        let dir = ($project_path | path dirname)
        let project_name = ($env.PWD | path basename)
        
        # Determine subdirectory component for naming
        let cwd = $env.PWD
        let relative = ($dir | str replace $cwd "" | str trim -c '/')
        
        # Build name: project-subdirectory or just project if at root
        let name = if ($relative | is-empty) {
            $project_name
        } else {
            let subdir = ($relative | str replace -a '/' '-')
            $"($project_name)-($subdir)"
        }
        
        return {
            path: $project_path
            context: $dir
            name: $name
            location: "project"
        }
    }
    
    # Check global config
    let global_base = ("~/.config/ocx" | path expand)
    let global_path = ($global_base | path join $dockerfile_path)
    
    if ($global_path | path exists) {
        let dir = ($global_path | path dirname)
        
        # Extract relative path from global_base to dir
        # e.g., ~/.config/ocx/rails/production/v7 -> rails/production/v7
        let relative = ($dir | str replace $global_base "" | str trim -c '/')
        
        # Convert path separators to dashes
        # e.g., rails/production/v7 -> rails-production-v7
        let name = ($relative | str replace -a '/' '-')
        
        return {
            path: $global_path
            context: $dir
            name: $name
            location: "global"
        }
    }
    
    # Not found - fail with clear error
    let project_checked = ($dockerfile_path | path expand)
    let global_checked = ($global_base | path join $dockerfile_path)
    
    error make {
        msg: $"Custom base Dockerfile not found: ($dockerfile_path)"
        label: {
            text: $"Checked:\n  1. Project: ($project_checked)\n  2. Global:  ($global_checked)"
        }
        help: $"Create a Dockerfile at one of these locations.\nSee docs/custom-base-template.md for templates."
    }
}
