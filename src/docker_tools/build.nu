use ./utils.nu [image-exists, resolve-dockerfile-path, get-image-name-base]
use ../config
use ../version
use ../nix_daemon.nu
use ../workspace.nu

export def main [
    --base
    --force
    --no-cache
] {
    let cfg = (config load)

    if $base {
        # For nix workflow, build nix-daemon and nix-dev images
        if $cfg.nix {
            print -e "Building nix daemon..."
            nix_daemon build $cfg --force=$force --no-cache=$no_cache
            
            print -e "Building nix dev environment..."
            build_nix_dev $cfg --force=$force --no-cache=$no_cache
        } else {
            # Building base layer for non-nix workflow
            if ($cfg.custom_base_dockerfile != null) {
                build_custom_base $cfg --force=$force --no-cache=$no_cache
            } else {
                build_ocx_base --force=$force --no-cache=$no_cache
            }
            
            # Then build OCX layer
            print -e "Base build complete, now building OCX..."
            build_ocx $cfg --force=$force --no-cache=$no_cache
        }
    } else {
        # Building OCX layer only
        if $cfg.nix {
            build_nix_dev $cfg --force=$force --no-cache=$no_cache
        } else {
            build_ocx $cfg --force=$force --no-cache=$no_cache
        }
    }
}

def build_ocx [cfg: record, --force, --no-cache] {
    # FILE_PWD points to the calling script's directory (main.nu in src/)
    # Dockerfiles are in the same directory as main.nu
    let context = $env.FILE_PWD
    let dockerfile = ($context | path join "Dockerfile.opencode")

    let version = (version resolve-version $cfg.opencode_version $cfg)

    let image_base = (get-image-name-base $cfg)

    # Determine base image
    let base_image = if ($cfg.custom_base_dockerfile != null) {
        let resolved = (resolve-dockerfile-path $cfg.custom_base_dockerfile)
        $"localhost/ocx-base-($resolved.name):latest"
    } else {
        "localhost/ocx-base:latest"
    }

    # Check if base exists, build if needed
    if (not (image-exists $base_image)) {
        print -e $"Base image (($base_image)) not found, building it first..."

        if ($cfg.custom_base_dockerfile != null) {
            build_custom_base $cfg --force=$force --no-cache=$no_cache
        } else {
            build_ocx_base --force=$force --no-cache=$no_cache
        }
        print -e "Base image ready, now building ocx..."
    }

    # Determine final image name
    let final_image = $"($image_base):($version)"
    let final_latest = $"($image_base):latest"

    let user_settings = (config resolve-user $cfg)
    let ws = (workspace get-workspace $cfg)

    # Resolve extra data directories from config to bake them into the image
    let extra_volumes = (config resolve-extra-volumes $cfg $user_settings.username $ws)

    # Only include target paths for volume-type mounts (not json mounts)
    let volume_dirs = ($extra_volumes
        | where type == "volume"
        | get target)
    let extra_dirs_arg = ($volume_dirs | str join " ")

    print -e $"Building OCX image: ($final_image)"
    print -e $"  Container user: ($user_settings.username) \(UID: ($user_settings.uid), GID: ($user_settings.gid)\)"
    if ($extra_dirs_arg != "") {
        print -e $"  Injecting extra volume directories: ($extra_dirs_arg)"
    }

    let cmd = (
        [
            "docker" "build"
            "-f" $dockerfile
            "--build-arg" $"BASE_IMAGE=($base_image)"
            "--build-arg" $"OPENCODE_VERSION=($version)"
            "--build-arg" $"USERNAME=($user_settings.username)"
            "--build-arg" $"UID=($user_settings.uid)"
            "--build-arg" $"GID=($user_settings.gid)"
            "--build-arg" $"EXTRA_DIRS=($extra_dirs_arg)"
            "-t" $final_image
            "-t" $final_latest
        ]
        | append (if $no_cache { ["--no-cache"] } else { [] })
        | append [$context]
    )

    run-external ...$cmd
}

def build_nix_dev [cfg: record, --force, --no-cache] {
    # Resolve opencode version (same mechanism as standard image)
    let version = (version resolve-version $cfg.opencode_version $cfg)
    # Ensure cfg has the resolved version for nix_daemon to use
    let cfg_with_version = ($cfg | merge { opencode_version: $version })
    let image_name = (nix_daemon get-dev-image-name $cfg_with_version)
    
    let context = $env.FILE_PWD
    let dockerfile = ($context | path join "Dockerfile.nix-dev")

    # Check versioned image to trigger rebuild on version change or Dockerfile change
    if (not $force) and (image-exists $image_name) {
        print -e $"Nix dev image ($image_name) already exists, skipping build \(use --force to rebuild\)"
        return
    }

    let user_settings = (config resolve-user $cfg)
    let ws = (workspace get-workspace $cfg)

    # Resolve extra data directories from config to bake them into the image
    let extra_volumes = (config resolve-extra-volumes $cfg $user_settings.username $ws)

    # Only include target paths for volume-type mounts (not bind mounts)
    let volume_dirs = ($extra_volumes
        | where type == "volume"
        | get target)
    let extra_dirs_arg = ($volume_dirs | str join " ")

    print -e $"Building nix dev image: ($image_name)"
    print -e $"  OpenCode version: v($version)"
    print -e $"  Container user: ($user_settings.username) \(UID: ($user_settings.uid), GID: ($user_settings.gid)\)"
    if ($extra_dirs_arg != "") {
        print -e $"  Injecting extra volume directories: ($extra_dirs_arg)"
    }

    let cmd = (
        [
            "docker" "build"
            "-f" $dockerfile
            "--build-arg" $"OPENCODE_VERSION=($version)"
            "--build-arg" $"USERNAME=($user_settings.username)"
            "--build-arg" $"UID=($user_settings.uid)"
            "--build-arg" $"GID=($user_settings.gid)"
            "--build-arg" $"EXTRA_DIRS=($extra_dirs_arg)"
            "-t" $image_name
        ]
        | append (if $no_cache { ["--no-cache"] } else { [] })
        | append [$context]
    )

    run-external ...$cmd
}

def build_custom_base [cfg: record, --force, --no-cache] {
    let user_settings = (config resolve-user $cfg)

    # Resolve Dockerfile path and derive name
    let resolved = (resolve-dockerfile-path $cfg.custom_base_dockerfile)

    let base_image_name = $"localhost/ocx-base-($resolved.name):latest"

    if (not $force) and (image-exists $base_image_name) {
        print -e $"Custom base image ($base_image_name) already exists, skipping build \(use --force to rebuild\)"
        return
    }

    print -e $"Building custom base '($resolved.name)' from ($resolved.location) config"
    print -e $"  Dockerfile: ($resolved.path)"
    print -e $"  Context: ($resolved.context)"

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

    if (not $force) and (image-exists $BASE_IMAGE) {
        print -e $"Base image ($BASE_IMAGE) already exists, skipping build \(use --force to rebuild\)"
        return
    }

    print -e "Building base ocx image..."

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

