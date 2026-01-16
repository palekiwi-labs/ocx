use ./ports.nu

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
    const BASE_IMAGE = "localhost/ocx-base:latest"
    const DOCKERFILE = "src/Dockerfile.base"

    # Skip build if image exists and not forcing
    if (not $force) and (image_exists $BASE_IMAGE) {
        print $"Base image ($BASE_IMAGE) already exists, skipping build \(use --force to rebuild\)"
        return
    }

    print "Building base ocx image..."

    let cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "-t" $BASE_IMAGE
        "."
    ]

    run-external ...$cmd
}

def image_exists [name: string] {
    (docker image inspect $name | complete).exit_code == 0
}

export def run [...args] {
    let config_dir = "~/.config/opencode" | path expand
    let config_mount_mode = "rw"
    let container_name = "ocx-test"
    let container_workspace = "/home/user/code"
    let image_name = "localhost/ocx:latest"
    let port = ports generate
    let user = "user"
    let workspace = "."

    if not (image_exists $image_name) {
        print $"Image ($image_name) not found, building it first..."
        build_ocx
    }

    mkdir $config_dir

    let cmd = [
        "docker" "run" "--rm" "-it"
        "--read-only"
        "--tmpfs" "/tmp:exec,nosuid,size=500m"
        "--tmpfs" "/workspace/tmp:exec,nosuid,size=500m"
        "--security-opt" "no-new-privileges"
        "--cap-drop" "ALL"
        "--network" "bridge"
        "--memory" "1024m"
        "--cpus" "1.0"
        "--pids-limit" "100"
        # "-p" $"($port):80"
        "-e" $"USER=($user)"
        "-e" "TERM="xterm-256color"
        "-e" "COLORTERM="truecolor"
        "-e" "FORCE_COLOR=1"
        # "-e" $"GEMINI_API_KEY=($env.GEMINI_API_KEY?)"
        "-e" "TMPDIR=/workspace/tmp"
        "-e" $"TZ=($env.TZ? | default 'Asia/Taipei')"
        "-v" $"ocx-cache-($port):/home/($user)/.cache:rw"
        "-v" $"ocx-local-($port):/home/($user)/.local:rw"
        "-v" $"($config_dir):/home/($user)/.config/opencode:($config_mount_mode)"
        "-v" "/etc/localtime:/etc/localtime:ro"
        "-v" $"($workspace):/home/user/code"
        "--workdir" $"($container_workspace)"
        "--name" $"($container_name)"
        $image_name "opencode" ...$args
    ]

    run-external ...$cmd
}
