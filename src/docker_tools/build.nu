use ./utils.nu [image_exists, resolve-dockerfile-path]
use ../config
use ../version

export def main [
    --base
    --force
    --no-cache
] {
    let cfg = (config load)
    
    if $base {
        # Building base layer
        if ($cfg.custom_base_dockerfile != null) {
            build_custom_base --force=$force --no-cache=$no_cache
        } else {
            build_ocx_base --force=$force --no-cache=$no_cache
        }
        # Then build OCX layer
        print "Base build complete, now building OCX..."
        build_ocx --force=$force --no-cache=$no_cache
    } else {
        # Building OCX layer only
        build_ocx --force=$force --no-cache=$no_cache
    }
}

def build_ocx [--force, --no-cache] {
    # FILE_PWD points to the calling script's directory (main.nu in src/)
    # Dockerfiles are in the same directory as main.nu
    let context = $env.FILE_PWD
    let dockerfile = ($context | path join "Dockerfile.opencode")
    
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
    if (not (image_exists $base_and_name.base_image)) {
        print $"Base image (($base_and_name.base_image)) not found, building it first..."

        if ($cfg.custom_base_dockerfile != null) {
            build_custom_base --force=$force --no-cache=$no_cache
        } else {
            build_ocx_base --force=$force --no-cache=$no_cache
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

    let cmd = (
        [
            "docker" "build"
            "-f" $dockerfile
            "--build-arg" $"BASE_IMAGE=($base_and_name.base_image)"
            "--build-arg" $"OPENCODE_VERSION=($version)"
            "--build-arg" $"USERNAME=($user_settings.username)"
            "--build-arg" $"UID=($user_settings.uid)"
            "--build-arg" $"GID=($user_settings.gid)"
            "-t" $final_image
            "-t" $final_latest
        ] 
        | append (if $no_cache { ["--no-cache"] } else { [] })
        | append [$context]
    )

    run-external ...$cmd
}

def build_custom_base [--force, --no-cache] {
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
    
    let cmd = (
        [
            "docker" "build"
            "-f" $resolved.path
            "--build-arg" $"USERNAME=($user_settings.username)"
            "--build-arg" $"UID=($user_settings.uid)"
            "--build-arg" $"GID=($user_settings.gid)"
            "-t" $base_image_name
        ]
        | append (if $no_cache { ["--no-cache"] } else { [] })
        | append [$resolved.context]
    )
    
    run-external ...$cmd
}

def build_ocx_base [--force, --no-cache] {
    const BASE_IMAGE = "localhost/ocx-base:latest"
    # FILE_PWD points to the calling script's directory (main.nu in src/)
    # Dockerfiles are in the same directory as main.nu
    let context = $env.FILE_PWD
    let dockerfile = ($context | path join "Dockerfile.base")

    if (not $force) and (image_exists $BASE_IMAGE) {
        print $"Base image ($BASE_IMAGE) already exists, skipping build \(use --force to rebuild\)"
        return
    }

    print "Building base ocx image..."

    let cmd = (
        [
            "docker" "build"
            "-f" $dockerfile
            "-t" $BASE_IMAGE
        ]
        | append (if $no_cache { ["--no-cache"] } else { [] })
        | append [$context]
    )

    run-external ...$cmd
}

