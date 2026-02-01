use ../config
use ../ports.nu

export def image_exists [name: string] {
    (docker image inspect $name | complete).exit_code == 0
}

export def resolve-container-name [cfg: record, port: int] {
    if $cfg.container_name != null {
        $"($cfg.container_name)-($port)"
    } else {
        let base = ($env.PWD | path basename)
        $"ocx-($base)-($port)"
    }
}

export def get-current-container-name [cfg: record] {
    let port = if $cfg.port == null { ports generate } else { $cfg.port }
    resolve-container-name $cfg $port
}

export def container-is-running [container_name: string] {
    let running = (docker ps --filter $"name=^($container_name)$" --format "{{.Names}}"
                   | complete
                   | get stdout
                   | str trim)

    not ($running | is-empty)
}

export def get-image-name-base [cfg: record] {
    let final_name = if ($cfg.custom_base_dockerfile != null) {
        let resolved = (resolve-dockerfile-path $cfg.custom_base_dockerfile)
        $resolved.name
    } else {
        null
    }

    if ($final_name != null) {
        $"localhost/ocx-($final_name)"
    } else {
        "localhost/ocx"
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

export def resolve-extra-volumes [cfg: record, user: string] {
    if $cfg.extra_data_volumes == null {
        return []
    }

    $cfg.extra_data_volumes | columns | each {|key|
        let raw_path = ($cfg.extra_data_volumes | get $key)
        let container_path = if ($raw_path | str starts-with "~/") {
            $"/home/($user)($raw_path | str substring 1..)"
        } else {
            $raw_path
        }

        { key: $key, path: $container_path }
    }
}
