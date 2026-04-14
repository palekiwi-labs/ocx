use ./utils.nu [image-exists, resolve-run-container-name, resolve-dockerfile-path, build-run-cmd, get-image-name-base]
use ./build.nu
use ../ports.nu
use ../workspace.nu
use ../config
use ../version
use ../volume_name.nu
use ../nix_daemon.nu

export def --wrapped main [...args] {
    let cfg = (config load)
    
    # Resolve user early (needed for flake detection paths)
    let user_settings = (config resolve-user $cfg)
    let user = $user_settings.username
    
    # Ensure nix daemon is running if nix workflow is enabled
    if $cfg.nix {
        nix_daemon ensure-running $cfg
    }

    # Detect user flake on the host
    let user_flake_host_dir = ("~/.config/ocx/nix" | path expand)
    let user_flake_present = ($user_flake_host_dir | path join "flake.nix" | path exists)
    
    # Resolve final command with optional user flake wrapping
    let final_opencode_command = if $cfg.nix {
        let base_cmd = if $cfg.nix_opencode_command != null {
            $cfg.nix_opencode_command
        } else {
            $cfg.opencode_command
        }
        # Wrap with user flake devShell if present, append "run"
        if $user_flake_present {
            ["nix" "develop" $"/home/($user)/.config/ocx/nix" "-c" ...$base_cmd "run"]
        } else {
            ["nix" "develop" "/nix/var/ocx" "-c" ...$base_cmd "run"]
        }
    } else {
        # Non-nix workflow: append "run" to the opencode command
        [...$cfg.opencode_command "run"]
    }

    let ws = workspace get-workspace $cfg

    # Determine image name based on config
    let image_base = (get-image-name-base $cfg)
    let version = (version resolve-version $cfg.opencode_version $cfg)
    let image_name = if $cfg.nix {
        if ($cfg.custom_base_dockerfile != null) {
            print -e "Warning: custom_base_dockerfile is not supported with nix workflow"
            print -e "         Using standard nix-dev image"
        }
        # For Nix mode, use the hashed tag which includes the version
        let cfg_with_version = ($cfg | merge { opencode_version: $version })
        nix_daemon get-dev-image-name $cfg_with_version
    } else {
        $"($image_base):($version)"
    }

    let port = if $cfg.port == null { ports generate } else { $cfg.port }
    let container_name = resolve-run-container-name $cfg $port
    let timezone = if $cfg.timezone == null { "UTC" } else { $cfg.timezone }
    
    let opencode_config_dir = $cfg.opencode_config_dir | path expand
    let env_file_name = if $cfg.env_file != null { $cfg.env_file } else { "ocx.env" }
    let global_env_path = ("~/.config/ocx/ocx.env" | path expand)
    let project_env_path = ($env_file_name | path expand)
    let volume_base = (volume_name resolve-volume-base-name $cfg)

    if not (image-exists $image_name) {
        if $cfg.nix {
            print -e $"Image ($image_name) not found, building nix dev environment..."
            build
        } else {
            let version = (version resolve-version $cfg.opencode_version $cfg)
            print -e $"Image ($image_name) not found, building OpenCode v($version)..."
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
