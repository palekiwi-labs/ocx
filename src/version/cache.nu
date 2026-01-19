const CACHE_DIR = "~/.cache/ocx"
const CACHE_FILE = $"($CACHE_DIR)/version-cache.json"
const CACHE_TTL_HOURS = 24

export def read-cache [] {
    let cache_path = ($CACHE_FILE | path expand)
    
    if not ($cache_path | path exists) {
        return null
    }
    
    try {
        let cache = open $cache_path
        
        if ($cache.version == null) or ($cache.fetched_at == null) {
            return null
        }
        
        let now = (date now | into int)
        let fetched = ($cache.fetched_at | into int)
        let age_seconds = ($now - $fetched)
        let age_hours = ($age_seconds / 3600)
        
        if $age_hours >= $CACHE_TTL_HOURS {
            return null
        }
        
        $cache
    } catch {
        null
    }
}

export def write-cache [version: string] {
    let cache_path = ($CACHE_FILE | path expand)
    let cache_dir = ($cache_path | path dirname)
    
    mkdir $cache_dir
    
    let now = (date now | into int)
    
    {
        version: $version,
        fetched_at: $now
    } | to json | save --force $cache_path
}

export def clear-cache [] {
    let cache_path = ($CACHE_FILE | path expand)
    
    if ($cache_path | path exists) {
        rm $cache_path
    }
}

export def get-cache-path [] {
    $CACHE_FILE | path expand
}
