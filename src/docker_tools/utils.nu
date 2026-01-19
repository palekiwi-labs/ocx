use ../config

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
    
    # Not found
    error make {
        msg: $"Dockerfile not found: ($dockerfile_path)"
        label: {
            text: $"Checked: ./($dockerfile_path) and ~/.config/ocx/($dockerfile_path)"
        }
        help: "Create a custom Dockerfile at one of these locations"
    }
}
