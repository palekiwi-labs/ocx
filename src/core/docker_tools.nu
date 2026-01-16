export def build [
    --base
    --force
] {
    if $base {
        build_ocx_base --force=$force
    } else {
        build_ocx
    }
}

def build_ocx [--force] {
    print "Building ocx image..."

    const BASE_IMAGE = "localhost/ocx-base:latest"
    const OPENCODE_VERSION = "1.1.23"
    const DOCKERFILE = "src/Dockerfile.opencode"

    mut cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "--build-arg" $"BASE_IMAGE=($BASE_IMAGE)"
        "--build-arg" $"OPENCODE_VERSION=($OPENCODE_VERSION)"
        "-t" $"localhost/ocx:($OPENCODE_VERSION)"
        "-t" "localhost/ocx:latest"
        "."
    ]

    run-external ...$cmd
}

def build_ocx_base [--force] {
    print "Building base ocx image..."

    const DOCKERFILE = "src/Dockerfile.base"

    let cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "-t" "localhost/ocx-base:latest"
        "."
    ]

    run-external ...$cmd
}

# # Check if Docker image exists
# export def "image-exists" [name: string] {
#     (docker image inspect $name | complete).exit_code == 0
# }

# Run container with full configuration
# export def run [config: record, workspace: record, args: list] {
#     # Build base docker run command
#     mut cmd = [
#         "docker" "run" "--rm" "-it"
#         "--read-only"
#         "--tmpfs" "/tmp:noexec,nosuid,size=500m"
#         "--tmpfs" "/workspace/tmp:exec,nosuid,size=500m"
#         "--security-opt" "no-new-privileges"
#         "--cap-drop" "ALL"
#         "--network" $config.network
#         "--memory" $config.memory
#         "--cpus" $config.cpus
#         "--pids-limit" ($config.pids_limit | into string)
#     ]
#
#     # Add port publishing if enabled
#     if $config.publish_port {
#         $cmd = ($cmd | append ["-p" $"($config.port):80"])
#     }
#
#     # Add environment variables
#     for entry in ($config.env | transpose key value) {
#         $cmd = ($cmd | append ["-e" $"($entry.key)=($entry.value)"])
#     }
#
#     # Add named volumes for cache and local
#     let volumes = (workspace volumes $config.port)
#     for vol in $volumes {
#         $cmd = ($cmd | append ["-v" $"($vol.name):($vol.container_path):($vol.mode)"])
#     }
#
#     # Add config directory mount
#     let config_dir_exists = ($config.config_dir | path exists)
#     if not $config_dir_exists {
#         mkdir $config.config_dir
#     }
#
#     let config_mount_mode = if $config.config_dir == $workspace.host_path {
#         "rw"
#     } else {
#         "ro"
#     }
#     $cmd = ($cmd | append ["-v" $"($config.config_dir):/home/user/.config/opencode:($config_mount_mode)"])
#
#     # Add workspace mount (unless it conflicts with config)
#     if $config.config_dir != $workspace.host_path {
#         $cmd = ($cmd | append ["-v" $"($workspace.host_path):($workspace.container_path):rw"])
#     }
#
#     # Add timezone mounts
#     if ("/etc/localtime" | path exists) {
#         $cmd = ($cmd | append ["-v" "/etc/localtime:/etc/localtime:ro"])
#     }
#     if ("/etc/timezone" | path exists) {
#         $cmd = ($cmd | append ["-v" "/etc/timezone:/etc/timezone:ro"])
#     }
#
#     # Add rgignore file if it exists
#     let rgignore_path = if ($env.OCX_RGIGNORE? | is-not-empty) {
#         $env.OCX_RGIGNORE
#     } else if ([$config.config_dir ".rgignore"] | path join | path exists) {
#         [$config.config_dir ".rgignore"] | path join
#     } else {
#         null
#     }
#
#     if $rgignore_path != null and ($rgignore_path | path exists) {
#         $cmd = ($cmd | append ["-v" $"($rgignore_path):/home/user/.rgignore:ro"])
#     }
#
#     # Add forbidden path mounts
#     use security.nu
#     let forbidden = (security forbidden-mounts $workspace.host_path $workspace.container_path $config.forbidden)
#     for mount in $forbidden {
#         if $mount.type == "tmpfs" {
#             $cmd = ($cmd | append ["--tmpfs" $"($mount.container_path):($mount.options)"])
#         } else if $mount.type == "bind" {
#             $cmd = ($cmd | append ["-v" $"($mount.source):($mount.container_path):($mount.mode)"])
#         }
#     }
#
#     # Add working directory
#     $cmd = ($cmd | append ["--workdir" $workspace.container_path])
#
#     # Add container name
#     $cmd = ($cmd | append ["--name" $config.container_name])
#
#     # Add image name
#     $cmd = ($cmd | append $config.image_name)
#
#     # Add opencode command
#     $cmd = ($cmd | append "opencode")
#
#     # Add user arguments
#     $cmd = ($cmd | append $args)
#
#     # Execute
#     run-external ...$cmd
# }
