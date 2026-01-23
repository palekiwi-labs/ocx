# Volume name resolution for data volumes

use ./git_utils.nu

# Resolve the base name for data volumes based on configuration
# Returns null if volumes should not be created
export def resolve-volume-base-name [cfg: record] {
    let mode = $cfg.data_volumes_mode
    
    # Check if user provided explicit volume name override
    if $cfg.data_volumes_name != null {
        return $cfg.data_volumes_name
    }
    
    match $mode {
        "never" => {
            null
        },
        "git" => {
            if (git_utils is-git-repo) {
                get-git-based-name
            } else {
                null
            }
        },
        "always" => {
            if (git_utils is-git-repo) {
                get-git-based-name
            } else {
                get-hash-based-name
            }
        },
        _ => {
            # Fallback to git mode for unknown values
            if (git_utils is-git-repo) {
                get-git-based-name
            } else {
                null
            }
        }
    }
}

# Generate git-based volume name
def get-git-based-name [] {
    let remote_url = (git_utils get-git-remote-url)
    
    if $remote_url == null {
        # No remote configured, fall back to hash of git root path
        let git_root = (git_utils get-git-root-path)
        if $git_root != null {
            return (generate-path-hash $git_root)
        }
        return null
    }
    
    $"ocx-git-($remote_url)"
}

# Generate hash-based volume name for non-git directories
def get-hash-based-name [] {
    let path = ($env.PWD | path expand)
    generate-path-hash $path
}

# Generate a volume name based on path hash
def generate-path-hash [path: string] {
    # Use first 8 characters of SHA256 hash
    let hash = ($path | hash sha256 | str substring 0..8)
    $"ocx-dir-($hash)"
}
