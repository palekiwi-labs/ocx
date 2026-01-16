use ./ports.nu
use ./workspace.nu
use ./config.nu

export def build [
    --base
    --force
] {
    if $base {
        build_ocx_base --force=$force
    } else {
        build_ocx --force=$force
    }
}

def build_ocx [--force] {
    const BASE_IMAGE = "localhost/ocx-base:latest"
    const OPENCODE_VERSION = "1.1.23"
    const DOCKERFILE = "src/Dockerfile.opencode"

    # Check if base image exists, build it if missing
    if not (image_exists $BASE_IMAGE) {
        print $"Base image ($BASE_IMAGE) not found, building it first..."
        build_ocx_base --force=false
        print "Base image ready, now building ocx..."
    }

    print "Building ocx image..."
    
    # Get user settings
    let cfg = (config load)
    let user_settings = (config resolve-user $cfg)

    mut cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "--build-arg" $"BASE_IMAGE=($BASE_IMAGE)"
        "--build-arg" $"OPENCODE_VERSION=($OPENCODE_VERSION)"
        "--build-arg" $"USERNAME=($user_settings.username)"
        "-t" $"localhost/ocx:($OPENCODE_VERSION)"
        "-t" "localhost/ocx:latest"
        "."
    ]

    run-external ...$cmd
}

def build_ocx_base [--force] {
    const BASE_IMAGE = "localhost/ocx-base:latest"
    const DOCKERFILE = "src/Dockerfile.base"

    # Skip build if image exists and not forcing
    if (not $force) and (image_exists $BASE_IMAGE) {
        print $"Base image ($BASE_IMAGE) already exists, skipping build \(use --force to rebuild\)"
        return
    }

    print "Building base ocx image..."
    
    # Get user settings
    let cfg = (config load)
    let user_settings = (config resolve-user $cfg)
    
    print $"Building with user: ($user_settings.username) \(UID: ($user_settings.uid), GID: ($user_settings.gid)\)"

    let cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "--build-arg" $"USERNAME=($user_settings.username)"
        "--build-arg" $"UID=($user_settings.uid)"
        "--build-arg" $"GID=($user_settings.gid)"
        "-t" $BASE_IMAGE
        "."
    ]

    run-external ...$cmd
}

def image_exists [name: string] {
    (docker image inspect $name | complete).exit_code == 0
}

export def run [...args] {
    # Get configuration
    let cfg = (config load)
    let ws = workspace get-workspace
    
    # Resolve values with auto-generation
    let port = if $cfg.port == null { ports generate } else { $cfg.port }
    let container_name = if $cfg.container_name == null {
        let parent = ($env.PWD | path dirname | path basename)
        let base = ($env.PWD | path basename)
        $"ocx-($parent)-($base)"
    } else {
        $cfg.container_name
    }
    let timezone = if $cfg.timezone == null { "Asia/Taipei" } else { $cfg.timezone }
    
    # Resolve user settings
    let user_settings = (config resolve-user $cfg)
    let user = $user_settings.username
    
    let config_dir = $cfg.config_dir | path expand
    
    # Detect mount conflicts: if CONFIG_DIR and WORKSPACE point to same location
    # and would mount to same container path, handle specially
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
    
    # Check if image exists, build if needed
    if not (image_exists $cfg.image_name) {
        print $"Image ($cfg.image_name) not found, building it first..."
        build_ocx
    }
    
    # Ensure config directory exists
    mkdir $config_dir
    
    # Build base docker command
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
    
    # Add port publishing if enabled
    if $cfg.publish_port {
        $cmd = ($cmd | append ["-p" $"($port):80"])
    }
    
    # Add environment variables
    $cmd = ($cmd | append [
        "-e" $"USER=($user)"
        "-e" "TERM=xterm-256color"
        "-e" "COLORTERM=truecolor"
        "-e" "FORCE_COLOR=1"
        "-e" "TMPDIR=/workspace/tmp"
        "-e" $"TZ=($timezone)"
    ])
    
    # Add volume mounts
    $cmd = ($cmd | append [
        "-v" $"ocx-cache-($port):/home/($user)/.cache:rw"
        "-v" $"ocx-local-($port):/home/($user)/.local:rw"
        "-v" $"($config_dir):($config_container_path):($config_mount_mode)"
        "-v" "/etc/localtime:/etc/localtime:ro"
    ])
    
    # Add workspace mount only if it doesn't conflict with config mount
    if not $skip_workspace_mount {
        $cmd = ($cmd | append ["-v" $"($ws.host_path):($ws.container_path):rw"])
    }
    
    # Add rgignore file mount if configured
    if $cfg.rgignore_file != null {
        let rgignore_path = $cfg.rgignore_file | path expand
        if ($rgignore_path | path exists) {
            $cmd = ($cmd | append ["-v" $"($rgignore_path):/home/($user)/.rgignore:ro"])
        }
    } else {
        # Check default location in config dir
        let default_rgignore = ($config_dir | path join ".rgignore")
        if ($default_rgignore | path exists) {
            $cmd = ($cmd | append ["-v" $"($default_rgignore):/home/($user)/.rgignore:ro"])
        }
    }
    
    # Add shadow mounts for forbidden paths
    for path in $cfg.forbidden_paths {
        let full_path = ($ws.host_path | path join $path)
        let container_forbidden_path = ($ws.container_path | path join $path)
        
        if ($full_path | path exists) {
            if ($full_path | path type) == "dir" {
                # Shadow mount directory with tmpfs
                $cmd = ($cmd | append ["--tmpfs" $"($container_forbidden_path):ro,noexec,nosuid,size=1k,mode=000"])
            } else {
                # Shadow mount file with /dev/null
                $cmd = ($cmd | append ["-v" $"/dev/null:($container_forbidden_path):ro"])
            }
        }
    }
    
    # Add workdir, name, and image
    $cmd = ($cmd | append [
        "--workdir" $ws.container_path
        "--name" $container_name
        $cfg.image_name "opencode" ...$args
    ])
    
    run-external ...$cmd
}
