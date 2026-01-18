use ./utils.nu image_exists
use ../config
use ../version
use ./overlay.nu

export def main [
    --base
    --force
    --force-overlay
] {
    if $force_overlay {
        let cfg = (config load)
        
        if not (overlay should-use-overlay $cfg) {
            error make {
                msg: "No overlay configured"
                help: "Set overlay_dockerfile in ocx.json to use --force-overlay"
            }
        }
        
        overlay build-overlay $cfg --force=true
        return
    }
    
    if $base {
        build_ocx_base --force=$force
    } else {
        build_ocx --force=$force
        
        let cfg = (config load)
        if (overlay should-use-overlay $cfg) {
            overlay build-overlay $cfg --force=$force
        }
    }
}

def build_ocx [--force] {
    const BASE_IMAGE = "localhost/ocx-base:latest"
    const DOCKERFILE = "src/Dockerfile.opencode"

    if not (image_exists $BASE_IMAGE) {
        print $"Base image ($BASE_IMAGE) not found, building it first..."
        build_ocx_base --force=false
        print "Base image ready, now building ocx..."
    }

    let cfg = (config load)
    let version = (version resolve-version $cfg.opencode_version)
    
    print $"Building ocx image for OpenCode v($version)..."
    
    let user_settings = (config resolve-user $cfg)

    mut cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "--build-arg" $"BASE_IMAGE=($BASE_IMAGE)"
        "--build-arg" $"OPENCODE_VERSION=($version)"
        "--build-arg" $"USERNAME=($user_settings.username)"
        "-t" $"localhost/ocx:($version)"
        "-t" "localhost/ocx:latest"
        "."
    ]

    run-external ...$cmd
}

def build_ocx_base [--force] {
    const BASE_IMAGE = "localhost/ocx-base:latest"
    const DOCKERFILE = "src/Dockerfile.base"

    if (not $force) and (image_exists $BASE_IMAGE) {
        print $"Base image ($BASE_IMAGE) already exists, skipping build \(use --force to rebuild\)"
        return
    }

    print "Building base ocx image..."
    
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
