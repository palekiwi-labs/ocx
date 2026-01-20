use ../config
use ../version

export def main [] {
    print "OCX Image Management

USAGE:
    ocx image <SUBCOMMAND> [OPTIONS]

SUBCOMMANDS:
    list         List all OCX images
    prune        Remove old images, keeping only latest version
    remove-all   Remove all OCX images

OPTIONS:
    --base       Filter/operate on base images only
    --final      Filter/operate on final OCX images only
    --json       Output as JSON (list only)

EXAMPLES:
    ocx image list                # List all OCX images
    ocx image list --base         # List only base images
    ocx image list --json         # List images in JSON format
    ocx image prune               # Remove old images, keep latest
    ocx image prune --base        # Prune only base images
    ocx image remove-all          # Remove all OCX images
    ocx image remove-all --final  # Remove only final OCX images

Use 'ocx image <subcommand> --help' for more information on a specific command."
}

# List all OCX images
export def list [
    --base     # Show only base images
    --final    # Show only final OCX images
    --json     # Output as JSON
] {
    let images = (list-ocx-images)
    
    let filtered = if $base {
        $images | filter-base-images
    } else if $final {
        $images | filter-final-images
    } else {
        $images
    }
    
    if ($filtered | is-empty) {
        print "No OCX images found"
        return
    }
    
    if $json {
        $filtered | to json
    } else {
        $filtered | table
    }
}

# Remove old OCX images, keeping only latest version
export def prune [
    --base     # Prune only base images
    --final    # Prune only final OCX images
] {
    let images = (list-ocx-images)
    
    let filtered = if $base {
        $images | filter-base-images
    } else if $final {
        $images | filter-final-images
    } else {
        $images
    }
    
    if ($filtered | is-empty) {
        print "No OCX images found to prune"
        return
    }
    
    let current_version = (get-current-version)
    
    # Determine which images to keep
    let to_keep = $filtered | where { |img|
        $img.tag == "latest" or $img.tag == $current_version
    }
    
    # Determine which images to remove
    let to_remove = $filtered | where { |img|
        $img.tag != "latest" and $img.tag != $current_version
    }
    
    if ($to_remove | is-empty) {
        print $"No old images to remove. Current version: ($current_version)"
        print $"Keeping ($to_keep | length) image\(s\) with 'latest' or '($current_version)' tags"
        return
    }
    
    print $"Removing ($to_remove | length) old image\(s\), keeping version ($current_version) and 'latest' tags..."
    
    for img in $to_remove {
        print $"  Removing ($img.repository):($img.tag) \(($img.size)\)"
        
        let result = (docker rmi $"($img.repository):($img.tag)" | complete)
        
        if $result.exit_code != 0 {
            print $"    Warning: Could not remove ($img.repository):($img.tag)"
            if ($result.stderr | str contains "image is being used") {
                print "    (Image is being used by a container. Stop the container first.)"
            }
        }
    }
    
    print $"\nPrune complete."
}

# Remove all OCX images
export def remove-all [
    --base     # Remove only base images
    --final    # Remove only final OCX images
] {
    let images = (list-ocx-images)
    
    let filtered = if $base {
        $images | filter-base-images
    } else if $final {
        $images | filter-final-images
    } else {
        $images
    }
    
    if ($filtered | is-empty) {
        print "No OCX images found to remove"
        return
    }
    
    print $"Removing ($filtered | length) OCX image\(s\)..."
    
    for img in $filtered {
        print $"  Removing ($img.repository):($img.tag) \(($img.size)\)"
        
        let result = (docker rmi $"($img.repository):($img.tag)" | complete)
        
        if $result.exit_code != 0 {
            print $"    Warning: Could not remove ($img.repository):($img.tag)"
            if ($result.stderr | str contains "image is being used") {
                print "    (Image is being used by a container. Stop the container first.)"
            }
        }
    }
    
    print $"\nRemove complete."
}

# Helper: List all OCX images
def list-ocx-images [] {
    let result = (
        docker images 
            --filter "reference=localhost/ocx*" 
            --format "{{.Repository}}|{{.Tag}}|{{.CreatedAt}}|{{.Size}}"
        | complete
    )
    
    if $result.exit_code != 0 {
        error make {
            msg: "Failed to list Docker images"
            label: {
                text: $"Docker error: ($result.stderr)"
            }
        }
    }
    
    if ($result.stdout | str trim | is-empty) {
        return []
    }
    
    $result.stdout 
        | lines 
        | where { |line| not ($line | is-empty) }
        | parse "{repository}|{tag}|{created}|{size}"
        | rename repository tag created size
}

# Helper: Filter to only base images
def filter-base-images [] {
    where { |img| $img.repository =~ "localhost/ocx-base" }
}

# Helper: Filter to only final OCX images (non-base)
def filter-final-images [] {
    where { |img| 
        ($img.repository =~ "localhost/ocx") and not ($img.repository =~ "localhost/ocx-base")
    }
}

# Helper: Get current/latest version from config or version cache
def get-current-version [] {
    let cfg = (config load)
    version resolve-version $cfg.opencode_version
}
