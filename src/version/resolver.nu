use ./cache.nu [read-cache, write-cache]
use ./github.nu [fetch-latest-release]

export def resolve-version [version: string, cfg: record] {
    let normalized = (normalize-version $version)
    
    if $normalized == "latest" {
        get-latest-version $cfg
    } else {
        if not (validate-semver $normalized) {
            error make {
                msg: $"Invalid version format: ($normalized)"
                label: {
                    text: "Version must be 'latest' or semantic version (e.g., 1.2.3)"
                }
            }
        }
        $normalized
    }
}

export def get-latest-version [cfg: record] {
    let cached = (read-cache $cfg.version_cache_ttl_hours)
    
    if $cached != null {
        return $cached.version
    }
    
    let release = (fetch-latest-release)
    
    if $release == null {
        error make {
            msg: "Unable to fetch latest version from GitHub"
            label: {
                text: "Check your network connection or specify an explicit version"
            }
        }
    }
    
    let version = (normalize-version $release.version)
    (write-cache $version)
    
    $version
}

export def normalize-version [version: string] {
    if $version == "latest" {
        return "latest"
    }
    
    let normalized = $version | str trim
    
    if ($normalized | str starts-with "v") {
        $normalized | str substring 1..
    } else {
        $normalized
    }
}

export def validate-semver [version: string]: nothing -> bool {
    if $version == "latest" {
        return true
    }
    
    # Remove build metadata (+...)
    let version_core = ($version | split row "+" | first)
    
    # Split pre-release from version (-)
    let base_and_pre = ($version_core | split row "-")
    let base_version = ($base_and_pre | first)
    
    # Validate base version (MAJOR.MINOR.PATCH)
    let parts = ($base_version | split row ".")
    
    if ($parts | length) != 3 {
        return false
    }
    
    for part in $parts {
        if ($part | str length) == 0 {
            return false
        }
        
        # Check if part is numeric
        try {
            $part | into int
            null
        } catch {
            return false
        }
    }
    
    true
}
