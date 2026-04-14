use ../config [resolve-extra-volumes]
use ../ports.nu
use ../shadow_mounts.nu
use ../opencode_env.nu
use ../volume_name.nu
use ../nix_daemon.nu

export def image-exists [name: string] {
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

export def resolve-run-container-name [cfg: record, port: int] {
    let base = resolve-container-name $cfg $port
    let suffix = (random uuid | str substring 0..7)
    $"($base)-run-($suffix)"
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
    if $cfg.nix {
        return "localhost/ocx"
    }

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

# Assemble a complete `docker run` argument list.
#
# Both interactive (ocx opencode) and headless (ocx run) container invocations
# share identical volume, network, security and environment setup.  The only
# behavioural differences are captured by two flags:
#
#   --interactive   add -it (allocate a TTY and keep stdin open)
#   --publish-port  add -p <port>:80
#
# All resolved values are passed in by the caller so that this function remains
# a pure assembler with no side-effects.
export def build-run-cmd [
    cfg: record,
    container_name: string,
    image_name: string,
    final_opencode_command: list,
    extra_args: list,
    ws: record,
    user_settings: record,
    opencode_config_dir: string,
    port: int,
    timezone: string,
    global_env_path: string,
    project_env_path: string,
    volume_base: any,       # string or null
    --interactive,          # add -it flags
    --publish-port,         # add -p <port>:80
] {
    let config_container_path = $"/home/($user_settings.username)/.config/opencode"
    let workspace_would_conflict = (
        ($opencode_config_dir == $ws.host_path) and
        ($config_container_path == $ws.container_path)
    )
    let skip_workspace_mount = $workspace_would_conflict

    if $workspace_would_conflict {
        print -e "Info: Config directory is the workspace - mounting as read-write"
    }

    mut cmd = ["docker" "run" "--rm"]

    if $interactive {
        $cmd = ($cmd | append ["-it"])
    }

    if $cfg.read_only {
        $cmd = ($cmd | append "--read-only")
    }

    if $cfg.add_host_docker_internal {
        $cmd = ($cmd | append ["--add-host" "host.docker.internal:host-gateway"])
    }

    $cmd = ($cmd | append [
        "--tmpfs" $"/tmp:exec,nosuid,size=($cfg.tmp_size),uid=($user_settings.uid),gid=($user_settings.gid)"
        "--tmpfs" $"/workspace/tmp:exec,nosuid,size=($cfg.workspace_tmp_size),uid=($user_settings.uid),gid=($user_settings.gid)"
        "--security-opt" "no-new-privileges"
        "--cap-drop" "ALL"
        "--network" $cfg.network
        "--memory" $cfg.memory
        "--cpus" ($cfg.cpus | into string)
        "--pids-limit" ($cfg.pids_limit | into string)
    ])

    if $publish_port {
        $cmd = ($cmd | append ["-p" $"($port):80"])
    }

    if ($global_env_path | path exists) {
        $cmd = ($cmd | append ["--env-file" $global_env_path])
    }

    if ($project_env_path | path exists) {
        $cmd = ($cmd | append ["--env-file" $project_env_path])
    }

    $cmd = ($cmd | append [
        "-e" $"USER=($user_settings.username)"
        "-e" "TERM=xterm-256color"
        "-e" "COLORTERM=truecolor"
        "-e" "FORCE_COLOR=1"
        "-e" "TMPDIR=/workspace/tmp"
        "-e" $"TZ=($timezone)"
    ])

    let opencode_env_args = (opencode_env generate-docker-args)
    $cmd = ($cmd | append $opencode_env_args)

    if $volume_base != null {
        $cmd = ($cmd | append [
            "-v" $"($volume_base)-cache:/home/($user_settings.username)/.cache:rw"
            "-v" $"($volume_base)-local:/home/($user_settings.username)/.local:rw"
        ])

        let extra_volumes = (resolve-extra-volumes $cfg $user_settings.username $ws)
        for vol in $extra_volumes {
            if $vol.type == "volume" and $volume_base == null {
                print $"Warning: Skipping volume mount '($vol.key)' because data_volumes_mode is 'never'"
                continue
            }

            let mount_spec = if $vol.type == "bind" {
                $"($vol.source):($vol.target):($vol.mode)"
            } else {
                let vol_name = if $vol.source != null {
                    $vol.source
                } else {
                    $"($volume_base)-($vol.key)"
                }
                $"($vol_name):($vol.target):($vol.mode)"
            }

            $cmd = ($cmd | append ["-v" $mount_spec])
        }
    }

    if $cfg.nix {
        let nix_volume = (nix_daemon get-volume-name $cfg)
        $cmd = ($cmd | append ["-v" $"($nix_volume):/nix:ro"])

        # Mount user flake directory if present
        let user_flake_host_dir = ("~/.config/ocx/nix" | path expand)
        if ($user_flake_host_dir | path join "flake.nix" | path exists) {
            $cmd = ($cmd | append ["-v" $"($user_flake_host_dir):/home/($user_settings.username)/.config/ocx/nix:rw"])
        }
    }

    $cmd = ($cmd | append [
        "-v" $"($opencode_config_dir):($config_container_path):rw"
        "-v" "/etc/localtime:/etc/localtime:ro"
    ])

    if not $skip_workspace_mount {
        $cmd = ($cmd | append ["-v" $"($ws.host_path):($ws.container_path):rw"])
    }

    if $cfg.rgignore_file != null {
        let rgignore_path = $cfg.rgignore_file | path expand
        if ($rgignore_path | path exists) {
            $cmd = ($cmd | append ["-v" $"($rgignore_path):/home/($user_settings.username)/.rgignore:ro"])
        }
    } else {
        let default_rgignore = ($opencode_config_dir | path join ".rgignore")
        if ($default_rgignore | path exists) {
            $cmd = ($cmd | append ["-v" $"($default_rgignore):/home/($user_settings.username)/.rgignore:ro"])
        }
    }

    let shadow_mount_args = (shadow_mounts generate
        $cfg.forbidden_paths
        $ws.host_path
        $ws.container_path
    )
    $cmd = ($cmd | append $shadow_mount_args)

    $cmd = ($cmd | append [
        "--workdir" $ws.container_path
        "--name" $container_name
        $image_name ...$final_opencode_command ...$extra_args
    ])

    $cmd
}
