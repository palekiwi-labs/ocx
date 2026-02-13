use ../config
use ../ports.nu
use ../git_utils.nu

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

        # Use git remote URL if inside a git repository
        # This ensures worktrees share the same image name (same remote = same image)
        let base_info = if (git_utils is-git-repo) {
            let remote_url = (git_utils get-git-remote-url)
            if $remote_url != null {
                # Extract repo name from sanitized remote URL
                # e.g., "github-com-palekiwi-labs-ocx" -> "ocx"
                let parts = ($remote_url | split row '-')
                let repo_name = ($parts | last)
                {
                    name: $repo_name
                    path: $env.PWD  # Use PWD for path checks (same as non-git)
                }
            } else {
                # No remote configured - fallback to directory name
                {
                    name: ($env.PWD | path basename)
                    path: $env.PWD
                }
            }
        } else {
            {
                name: ($env.PWD | path basename)
                path: $env.PWD
            }
        }

        # Determine subdirectory component for naming
        # Only calculate relative path if Dockerfile is actually inside base path
        # Git worktrees are separate directories, so treat them as root level
        let is_inside = if ($dir == $base_info.path) {
            # Same directory - at root
            true
        } else if ($dir | str starts-with $"($base_info.path)/") {
            # Starts with base_path/ - is a subdirectory
            true
        } else {
            # Not inside base path (e.g., git worktree in sibling directory)
            false
        }

        let relative = if $is_inside {
            ($dir | str replace $base_info.path "" | str trim -c '/')
        } else {
            # Outside base path - treat as root level
            ""
        }

        # Build name: project-subdirectory or just project if at root
        let name = if ($relative | is-empty) {
            $base_info.name
        } else {
            let subdir = ($relative | str replace -a '/' '-')
            $"($base_info.name)-($subdir)"
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
        let vol_config = ($cfg.extra_data_volumes | get $key)

        # Extract fields with defaults
        let target = $vol_config.target
        let mode = ($vol_config.mode? | default "rw")
        let vol_type = ($vol_config.type? | default "volume")

        # Expand tilde in target path
        let container_target = if ($target | str starts-with "~/") {
            $"/home/($user)($target | str substring 1..)"
        } else {
            $target
        }

        # Determine source
        let source = if ($vol_config.source? != null) {
            $vol_config.source
        } else {
            # Default source for volumes: ${volume_base}-${key}
            # For bind mounts, source is required (caught by validation)
            null
        }

        {
            key: $key,
            source: $source,
            target: $container_target,
            mode: $mode,
            type: $vol_type
        }
    }
}
