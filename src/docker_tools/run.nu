use ./utils.nu [image_exists, resolve-run-container-name, resolve-dockerfile-path, build-run-cmd]
use ./build.nu
use ../ports.nu
use ../workspace.nu
use ../config
use ../version
use ../volume_name.nu
use ../nix_daemon.nu

export def --wrapped main [...args] {
    let cfg = (config load)

    # Ensure nix daemon is running if nix workflow is enabled
    if $cfg.nix {
        nix_daemon ensure-running $cfg
        nix_daemon ensure-default-flake $cfg
    }

    # Resolve final command - append "run" to the base opencode command
    let final_opencode_command = if $cfg.nix {
        let base_cmd = if $cfg.nix_opencode_command != null {
            $cfg.nix_opencode_command
        } else {
            $cfg.opencode_command
        }
        # Always wrap in default devshell for nix workflow, append "run"
        ["nix" "develop" "/nix/var/ocx" "-c" ...$base_cmd "run"]
    } else {
        # Non-nix workflow: append "run" to the opencode command
        [...$cfg.opencode_command "run"]
    }

    let ws = workspace get-workspace $cfg

    # Determine image name based on config
    let image_name = if $cfg.nix {
        if ($cfg.custom_base_dockerfile != null) {
            print "Warning: custom_base_dockerfile is not supported with nix workflow"
            print "         Using standard nix-dev image"
        }
        "localhost/ocx-nix:latest"
    } else {
        let version = (version resolve-version $cfg.opencode_version $cfg)
        if ($cfg.custom_base_dockerfile != null) {
            let resolved = (resolve-dockerfile-path $cfg.custom_base_dockerfile)
            $"localhost/ocx-($resolved.name):($version)"
        } else {
            $"localhost/ocx:($version)"
        }
    }

    let port = if $cfg.port == null { ports generate } else { $cfg.port }
    let container_name = resolve-run-container-name $cfg $port
    let timezone = if $cfg.timezone == null { "UTC" } else { $cfg.timezone }
    let user_settings = (config resolve-user $cfg)
    let opencode_config_dir = $cfg.opencode_config_dir | path expand
    let env_file_name = if $cfg.env_file != null { $cfg.env_file } else { "ocx.env" }
    let global_env_path = ("~/.config/ocx/ocx.env" | path expand)
    let project_env_path = ($env_file_name | path expand)
    let volume_base = (volume_name resolve-volume-base-name $cfg)

    if not (image_exists $image_name) {
        if $cfg.nix {
            print $"Image ($image_name) not found, building nix dev environment..."
            build
        } else {
            let version = (version resolve-version $cfg.opencode_version $cfg)
            print $"Image ($image_name) not found, building OpenCode v($version)..."
            build
        }
    }

    mkdir $opencode_config_dir

    # Headless: no --interactive, no --publish-port
    let cmd = (build-run-cmd $cfg $container_name $image_name $final_opencode_command $args
        $ws $user_settings $opencode_config_dir $port $timezone
        $global_env_path $project_env_path $volume_base)

    run-external ...$cmd
}
