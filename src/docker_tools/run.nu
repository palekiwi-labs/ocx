use ./utils.nu [image_exists, resolve-container-name]
use ./build.nu
use ./overlay.nu
use ../ports.nu
use ../workspace.nu
use ../config
use ../shadow_mounts.nu
use ../version

export def main [...args] {
    let cfg = (config load)
    let ws = workspace get-workspace
    
    let version = (version resolve-version $cfg.opencode_version)
    
    let image_name = if (overlay should-use-overlay $cfg) {
        let overlay_image = overlay resolve-overlay-image-name $cfg $version
        
        if not (image_exists $overlay_image) {
            print $"Overlay image ($overlay_image) not found, building..."
            overlay build-overlay $cfg --force=false
        }
        
        $overlay_image
    } else {
        let ocx_image = $"localhost/ocx:($version)"
        
        if not (image_exists $ocx_image) {
            print $"Image ($ocx_image) not found, building OpenCode v($version)..."
            build
        }
        
        $ocx_image
    }
    
    let port = if $cfg.port == null { ports generate } else { $cfg.port }
    let container_name = resolve-container-name $port
    let timezone = if $cfg.timezone == null { "Asia/Taipei" } else { $cfg.timezone }
    
    let user_settings = (config resolve-user $cfg)
    let user = $user_settings.username
    
    let config_dir = $cfg.config_dir | path expand
    
    let config_container_path = $"/home/($user)/.config/opencode"
    let workspace_would_conflict = (
        ($config_dir == $ws.host_path) and 
        ($config_container_path == $ws.container_path)
    )
    
    let config_mount_mode = if $workspace_would_conflict { "rw" } else { "ro" }
    let skip_workspace_mount = $workspace_would_conflict
    
    if $workspace_would_conflict {
        print "Info: Config directory is the workspace - mounting as read-write"
    }
    
    if not (image_exists $image_name) {
        print $"Image ($image_name) not found, building OpenCode v($version)..."
        build
    }
    
    mkdir $config_dir
    
    mut cmd = [
        "docker" "run" "--rm" "-it"
        "--read-only"
        "--tmpfs" $"/tmp:exec,nosuid,size=($cfg.tmp_size)"
        "--tmpfs" $"/workspace/tmp:exec,nosuid,size=($cfg.workspace_tmp_size)"
        "--security-opt" "no-new-privileges"
        "--cap-drop" "ALL"
        "--network" $cfg.network
        "--memory" $cfg.memory
        "--cpus" ($cfg.cpus | into string)
        "--pids-limit" ($cfg.pids_limit | into string)
    ]
    
    if $cfg.publish_port {
        $cmd = ($cmd | append ["-p" $"($port):80"])
    }
    
    $cmd = ($cmd | append [
        "-e" $"USER=($user)"
        "-e" "TERM=xterm-256color"
        "-e" "COLORTERM=truecolor"
        "-e" "FORCE_COLOR=1"
        "-e" "TMPDIR=/workspace/tmp"
        "-e" $"TZ=($timezone)"
    ])
    
    $cmd = ($cmd | append [
        "-v" $"ocx-cache-($port):/home/($user)/.cache:rw"
        "-v" $"ocx-local-($port):/home/($user)/.local:rw"
        "-v" $"($config_dir):($config_container_path):($config_mount_mode)"
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
        let default_rgignore = ($config_dir | path join ".rgignore")
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
