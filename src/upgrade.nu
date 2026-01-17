use version
use config
use docker_tools build

export def main [--check] {
    print "Checking for OpenCode updates..."
    
    let cfg = (config load)
    let current = (version resolve-version $cfg.opencode_version)
    
    let latest_info = (version fetch-latest-release)
    
    if $latest_info == null {
        print "Unable to check for updates (network error or rate limit)"
        return
    }
    
    let latest = (version normalize-version $latest_info.version)
    
    if $current == $latest {
        print $"Already up to date: OpenCode v($current)"
        return
    }
    
    print $"New version available: v($latest) \(current: v($current)\)"
    
    if ($latest_info.notes != null) {
        print "Release notes:"
        print $latest_info.notes
    }
    
    if $check {
        return
    }
    
    let response = (input $"Update to v($latest)? [y/N] ")
    
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
