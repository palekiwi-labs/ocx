use ./utils.nu [image_exists, resolve-dockerfile-path]
use ../config
use ../version

export def main [
    --base
    --force
] {
    let cfg = (config load)
    
    if $base {
        # Building base layer
        if ($cfg.custom_base_dockerfile != null) {
            build_custom_base --force=$force
        } else {
            build_ocx_base --force=$force
        }
    } else {
        # Building OCX layer
        build_ocx --force=$force
    }
}

def build_ocx [--force] {
    const DOCKERFILE = "src/Dockerfile.opencode"
    
    let cfg = (config load)
    let version = (version resolve-version $cfg.opencode_version)
    
    # Determine base image and final image name
    let base_and_name = if ($cfg.custom_base_dockerfile != null) {
        let resolved = (resolve-dockerfile-path $cfg.custom_base_dockerfile)
        {
            base_image: $"localhost/ocx-base-($resolved.name):latest"
            final_name: $resolved.name
        }
    } else {
        {
            base_image: "localhost/ocx-base:latest"
            final_name: null
        }
    }
    
    # Check if base exists, build if needed
    if not (image_exists $base_and_name.base_image) {
        print $"Base image (($base_and_name.base_image)) not found, building it first..."
        if ($cfg.custom_base_dockerfile != null) {
            build_custom_base --force=false
        } else {
            build_ocx_base --force=false
        }
        print "Base image ready, now building ocx..."
    }
    
    # Determine final image name
    let final_image = if ($base_and_name.final_name != null) {
        $"localhost/ocx-($base_and_name.final_name):($version)"
    } else {
        $"localhost/ocx:($version)"
    }
    
    let final_latest = if ($base_and_name.final_name != null) {
        $"localhost/ocx-($base_and_name.final_name):latest"
    } else {
        "localhost/ocx:latest"
    }
    
    let user_settings = (config resolve-user $cfg)
    
    print $"Building OCX image: ($final_image)"
    print $"  Container user: ($user_settings.username) \(UID: ($user_settings.uid), GID: ($user_settings.gid)\)"

    let cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "--build-arg" $"BASE_IMAGE=($base_and_name.base_image)"
        "--build-arg" $"OPENCODE_VERSION=($version)"
        "--build-arg" $"USERNAME=($user_settings.username)"
        "--build-arg" $"UID=($user_settings.uid)"
        "--build-arg" $"GID=($user_settings.gid)"
        "-t" $final_image
        "-t" $final_latest
        "."
    ]

    run-external ...$cmd
}

def build_custom_base [--force] {
    let cfg = (config load)
    let user_settings = (config resolve-user $cfg)
    
    # Resolve Dockerfile path and derive name
    let resolved = (resolve-dockerfile-path $cfg.custom_base_dockerfile)
    
    let base_image_name = $"localhost/ocx-base-($resolved.name):latest"
    
    if (not $force) and (image_exists $base_image_name) {
        print $"Custom base image ($base_image_name) already exists, skipping build \(use --force to rebuild\)"
        return
    }
    
    print $"Building custom base '($resolved.name)' from ($resolved.location) config"
    print $"  Dockerfile: ($resolved.path)"
    print $"  Context: ($resolved.context)"
    
    let cmd = [
        "docker" "build"
        "-f" $resolved.path
        "--build-arg" $"USERNAME=($user_settings.username)"
        "--build-arg" $"UID=($user_settings.uid)"
        "--build-arg" $"GID=($user_settings.gid)"
        "-t" $base_image_name
        $resolved.context
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

    let cmd = [
        "docker" "build"
        "-f" $DOCKERFILE
        "-t" $BASE_IMAGE
        "."
    ]

    run-external ...$cmd
}
