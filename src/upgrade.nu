use version
use config
use docker_tools build

export def main [--check] {
    print "Checking for OpenCode updates..."
    
    let cfg = (config load)
    let latest_info = (version fetch-latest-release)
    
    if $latest_info == null {
        print "Unable to check for updates (network error or rate limit)"
        return
    }
    
    let latest = (version normalize-version $latest_info.version)
    
    if $cfg.opencode_version == "latest" {
        handle-latest-config $latest $latest_info $check
    } else {
        handle-explicit-config $cfg.opencode_version $latest $latest_info $check
    }
}

def handle-explicit-config [
    config_version: string,
    latest: string,
    latest_info: record,
    check: bool
] {
    let normalized_config = (version normalize-version $config_version)
    
    if $normalized_config == $latest {
        print $"Already up to date: OpenCode v($normalized_config)"
        return
    }
    
    print $"New version available: v($latest) (current config: v($normalized_config))"
    
    if ($latest_info.notes != null) {
        print ""
        print "Release notes:"
        print $latest_info.notes
        print ""
    }
    
    if $check {
        return
    }
    
    let response = (input $"Update config to v($latest) and rebuild? [y/N] ")
    
    if ($response | str downcase) != "y" {
        print "Update cancelled"
        return
    }
    
    update-global-config $latest
    
    print $"Updated configuration to v($latest)"
    print "Rebuilding image..."
    
    build --force=true
    
    print $"OpenCode v($latest) is ready!"
}

def handle-latest-config [
    latest: string,
    latest_info: record,
    check: bool
] {
    let local_versions = (version get-local-semantic-versions)
    
    if ($local_versions | is-empty) {
        print "No OpenCode images found (or version tags missing)."
        print $"Latest available: v($latest)"
        print ""
        print "Run 'ocx build' to create your first image."
        return
    }
    
    if $latest in $local_versions {
        print $"Already up to date: OpenCode v($latest)"
        return
    }
    
    print $"New version available: v($latest)"
    
    if ($latest_info.notes != null) {
        print ""
        print "Release notes:"
        print $latest_info.notes
        print ""
    }
    
    if $check {
        return
    }
    
    let response = (input $"Build v($latest)? [y/N] ")
    
    if ($response | str downcase) != "y" {
        print "Update cancelled"
        return
    }
    
    print "Rebuilding image..."
    
    build --force=true
    
    print $"OpenCode v($latest) is ready!"
}

def update-global-config [version: string] {
    let config_info = (config get-with-sources)
    let global_path = $config_info.files.global
    
    mkdir ($global_path | path dirname)
    
    let current = if ($global_path | path exists) {
        open $global_path
    } else {
        {}
    }
    
    let updated = ($current | upsert opencode_version $version)
    
    $updated | to json | save --force $global_path
}
