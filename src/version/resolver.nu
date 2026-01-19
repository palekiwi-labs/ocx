use ./cache.nu [read-cache, write-cache]
use ./github.nu [fetch-latest-release]

export def resolve-version [version: string] {
    let normalized = (normalize-version $version)
    
    if $normalized == "latest" {
        get-latest-version
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

export def get-latest-version [] {
    let cached = (read-cache)
    
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
    
    let parts = ($version | split row ".")
    
    if ($parts | length) != 3 {
        return false
    }
    
    for part in $parts {
        if ($part | str length) == 0 {
            return false
        }
        
        if ($part | into int) == null {
            return false
        }
    }
    
    true
}
