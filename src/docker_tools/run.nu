use ./utils.nu [image_exists, resolve-container-name, resolve-dockerfile-path, resolve-extra-volumes]
use ./build.nu
use ../ports.nu
use ../workspace.nu
use ../config
use ../shadow_mounts.nu
use ../version
use ../volume_name.nu
use ../opencode_env.nu

export def main [...args] {
    let cfg = (config load)
    let ws = workspace get-workspace $cfg
    
    let version = (version resolve-version $cfg.opencode_version $cfg)
    
    # Determine image name based on config
    let image_name = if ($cfg.custom_base_dockerfile != null) {
        let resolved = (resolve-dockerfile-path $cfg.custom_base_dockerfile)
        $"localhost/ocx-($resolved.name):($version)"
    } else {
        $"localhost/ocx:($version)"
    }
    
    let port = if $cfg.port == null { ports generate } else { $cfg.port }
    let container_name = resolve-container-name $cfg $port
    let timezone = if $cfg.timezone == null { "UTC" } else { $cfg.timezone }
    
    let user_settings = (config resolve-user $cfg)
    let user = $user_settings.username
    
    let opencode_config_dir = $cfg.opencode_config_dir | path expand
    
    # Resolve env file
    let env_file_name = if $cfg.env_file != null { $cfg.env_file } else { "ocx.env" }
    
    # Global is always ocx.env to ensure stability
    let global_env_path = ("~/.config/ocx/ocx.env" | path expand)
    
    # Project respects the configured name
    let project_env_path = ($env_file_name | path expand)
    
    let config_container_path = $"/home/($user)/.config/opencode"
    let workspace_would_conflict = (
        ($opencode_config_dir == $ws.host_path) and 
        ($config_container_path == $ws.container_path)
    )
    
    let config_mount_mode = "rw"
    let skip_workspace_mount = $workspace_would_conflict
    
    if $workspace_would_conflict {
        print "Info: Config directory is the workspace - mounting as read-write"
    }
    
    if not (image_exists $image_name) {
        print $"Image ($image_name) not found, building OpenCode v($version)..."
        build
    }
    
    mkdir $opencode_config_dir
    
    mut cmd = [
        "docker" "run" "--rm" "-it"
    ]
    
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
    
    if $cfg.publish_port {
        $cmd = ($cmd | append ["-p" $"($port):80"])
    }

    if ($global_env_path | path exists) {
        $cmd = ($cmd | append ["--env-file" $global_env_path])
    }
    
    if ($project_env_path | path exists) {
        $cmd = ($cmd | append ["--env-file" $project_env_path])
    }
    
    $cmd = ($cmd | append [
        "-e" $"USER=($user)"
        "-e" "TERM=xterm-256color"
        "-e" "COLORTERM=truecolor"
        "-e" "FORCE_COLOR=1"
        "-e" "TMPDIR=/workspace/tmp"
        "-e" $"TZ=($timezone)"
    ])
    
    # Add OpenCode passthrough environment variables
    let opencode_env_args = (opencode_env generate-docker-args)
    $cmd = ($cmd | append $opencode_env_args)
    
    # Add data volumes based on configuration
    let volume_base = (volume_name resolve-volume-base-name $cfg)
    
    if $volume_base != null {
        $cmd = ($cmd | append [
            "-v" $"($volume_base)-cache:/home/($user)/.cache:rw"
            "-v" $"($volume_base)-local:/home/($user)/.local:rw"
        ])
        
        # Add extra data volumes
        let extra_volumes = (resolve-extra-volumes $cfg $user)
        for vol in $extra_volumes {
            if $vol.type == "volume" and $volume_base == null {
                print $"Warning: Skipping volume mount '($vol.key)' because data_volumes_mode is 'never'"
                continue
            }
            
            let mount_spec = if $vol.type == "bind" {
                # Bind mount: source:target:mode
                $"($vol.source):($vol.target):($vol.mode)"
            } else {
                # Volume mount: ${volume_base}-${source_or_key}:target:mode
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
    
    $cmd = ($cmd | append [
        "-v" $"($opencode_config_dir):($config_container_path):($config_mount_mode)"
        "-v" "/etc/localtime:/etc/localtime:ro"
    ])
    
    if not $skip_workspace_mount {
        $cmd = ($cmd | append ["-v" $"($ws.host_path):($ws.container_path):rw"])
    }
    
    if $cfg.rgignore_file != null {
        let rgignore_path = $cfg.rgignore_file | path expand
        if ($rgignore_path | path exists) {
            $cmd = ($cmd | append ["-v" $"($rgignore_path):/home/($user)/.rgignore:ro"])
        }
    } else {
        let default_rgignore = ($opencode_config_dir | path join ".rgignore")
        if ($default_rgignore | path exists) {
            $cmd = ($cmd | append ["-v" $"($default_rgignore):/home/($user)/.rgignore:ro"])
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
        $image_name "opencode" ...$args
    ])
    
    run-external ...$cmd
}
