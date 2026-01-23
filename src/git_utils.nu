# Git utility functions for volume name generation

# Check if current directory is inside a git repository
export def is-git-repo [] {
    let result = (git rev-parse --is-inside-work-tree | complete)
    $result.exit_code == 0
}

# Get the git root directory path
export def get-git-root-path [] {
    if not (is-git-repo) {
        return null
    }
    
    let result = (git rev-parse --show-toplevel | complete)
    if $result.exit_code == 0 {
        $result.stdout | str trim
    } else {
        null
    }
}

# Get the git remote URL and sanitize it for use in volume names
# Prefers 'origin', falls back to first available remote
export def get-git-remote-url [] {
    if not (is-git-repo) {
        return null
    }
    
    # Try to get origin remote first
    let origin_result = (git config --get remote.origin.url | complete)
    
    let remote_url = if $origin_result.exit_code == 0 {
        $origin_result.stdout | str trim
    } else {
        # Fall back to first available remote
        let remotes = (git remote | complete | get stdout | str trim | lines)
        if ($remotes | is-empty) {
            return null
        }
        
        let first_remote = ($remotes | first)
        let url_result = (git config --get $"remote.($first_remote).url" | complete)
        
        if $url_result.exit_code == 0 {
            $url_result.stdout | str trim
        } else {
            return null
        }
    }
    
    if ($remote_url | is-empty) {
        return null
    }
    
    # Sanitize the URL for use in volume names
    sanitize-remote-url $remote_url
}

# Sanitize a git remote URL for use in Docker volume names
# Converts URLs to lowercase alphanumeric + hyphens only
def sanitize-remote-url [url: string] {
    mut sanitized = $url
    
    # Remove common prefixes
    $sanitized = ($sanitized | str replace -r '^https?://' '')
    $sanitized = ($sanitized | str replace -r '^git@' '')
    $sanitized = ($sanitized | str replace -r '^ssh://' '')
    $sanitized = ($sanitized | str replace -r '^git://' '')
    
    # Remove .git suffix
    $sanitized = ($sanitized | str replace -r '\.git$' '')
    
    # Replace colons (from SSH URLs like git@github.com:user/repo)
    $sanitized = ($sanitized | str replace -a ':' '/')
    
    # Replace slashes, dots, and other special chars with hyphens
    $sanitized = ($sanitized | str replace -a '/' '-')
    $sanitized = ($sanitized | str replace -a '.' '-')
    $sanitized = ($sanitized | str replace -a '_' '-')
    $sanitized = ($sanitized | str replace -a '@' '-')
    
    # Remove any remaining non-alphanumeric characters except hyphens
    $sanitized = ($sanitized | str replace -r '[^a-zA-Z0-9-]' '')
    
    # Convert to lowercase
    $sanitized = ($sanitized | str downcase)
    
    # Remove duplicate hyphens
    $sanitized = ($sanitized | str replace -r '-+' '-')
    
    # Trim hyphens from start and end
    $sanitized = ($sanitized | str trim -c '-')
    
    # Docker volume names have a limit, use hash if too long
    if ($sanitized | str length) > 200 {
        # Use hash of original URL to keep it short
        let hash = ($url | hash md5 | str substring 0..15)
        $"git-($hash)"
    } else {
        $sanitized
    }
}
