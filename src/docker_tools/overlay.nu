use ../config
use ../version
use ./utils.nu image_exists

export def should-use-overlay [cfg: record]: nothing -> bool {
    $cfg.overlay_dockerfile != null
}

export def resolve-overlay-dockerfile [cfg: record]: nothing -> any {
    let dockerfile_rel = $cfg.overlay_dockerfile
    
    let project_path = ($dockerfile_rel | path expand)
    if ($project_path | path exists) {
        return {
            path: $project_path
            context: ($project_path | path dirname)
            source: "project"
        }
    }
    
    let global_path = ("~/.config/ocx" | path join $dockerfile_rel | path expand)
    if ($global_path | path exists) {
        return {
            path: $global_path
            context: ($global_path | path dirname)
            source: "global"
        }
    }
    
    error make {
        msg: $"Overlay Dockerfile not found: ($dockerfile_rel)"
        help: $"Checked:\n  - ($project_path)\n  - ($global_path)"
    }
}

export def resolve-overlay-image-name [cfg: record, version: string]: nothing -> string {
    let name = if $cfg.overlay_image_name != null {
        $cfg.overlay_image_name
    } else {
        default-overlay-name
    }
    
    $"localhost/ocx-($name):($version)"
}

export def build-overlay [cfg: record, --force]: nothing -> nothing {
    let dockerfile_info = resolve-overlay-dockerfile $cfg
    let version = (version resolve-version $cfg.opencode_version)
    let image_name = resolve-overlay-image-name $cfg $version
    let base_image = $"localhost/ocx:($version)"
    
    if not (image_exists $base_image) {
        error make {
            msg: $"Base image ($base_image) not found"
            help: "Run 'ocx build' first to build the base ocx image"
        }
    }
    
    if (not $force) and (image_exists $image_name) {
        print $"Overlay image ($image_name) already exists \(use --force-overlay to rebuild\)"
        return
    }
    
    print $"Building overlay image ($image_name) from ($dockerfile_info.source)..."
    print $"  Dockerfile: ($dockerfile_info.path)"
    print $"  Context: ($dockerfile_info.context)"
    
    let user_settings = (config resolve-user $cfg)
    
    mut cmd = [
        "docker" "build"
        "-f" $dockerfile_info.path
        "--build-arg" $"BASE_IMAGE=($base_image)"
        "--build-arg" $"OCX_VERSION=($version)"
        "--build-arg" $"USERNAME=($user_settings.username)"
        "-t" $image_name
    ]
    
    if $force {
        $cmd = ($cmd | append "--no-cache")
    }
    
    $cmd = ($cmd | append $dockerfile_info.context)
    
    run-external ...$cmd
}

def default-overlay-name []: nothing -> string {
    $env.PWD | path basename
}
