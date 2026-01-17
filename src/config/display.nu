use loader.nu get-with-sources

export def show [--json] {
    let result = get-with-sources
    
    if $json {
        print ($result.config | to json --indent 2)
    } else {
        print "=== OCX Configuration ==="
        print ""
        print "Final merged configuration:"
        print ($result.config | to json --indent 2)
        print ""
        print "Config file locations:"
        print $"  Global:  ($result.files.global) \(exists: ($result.files.global_exists)\)"
        print $"  Project: ($result.files.project) \(exists: ($result.files.project_exists)\)"
    }
}

export def show-sources [
    --json  # Output as JSON only
] {
    let result = get-with-sources
    
    if $json {
        # Build JSON structure with config, sources, and file info
        let output = {
            config: $result.config
            sources: $result.sources
            files: $result.files
        }
        print ($output | to json --indent 2)
    } else {
        print "=== OCX Configuration Sources ==="
        print ""
        print $"Priority: env vars > project > global > default"
        print ""
        
        # Build table with config values and sources
        mut rows = []
        for key in ($result.config | columns) {
            let value = $result.config | get $key
            let source = $result.sources | get $key
            
            $rows = ($rows | append {
                key: $key
                value: ($value | to json --raw)
                source: $source
            })
        }
        
        print ($rows | table)
        print ""
        print "Config files:"
        print $"  Global:  ($result.files.global) (char lparen)exists: ($result.files.global_exists)(char rparen)"
        print $"  Project: ($result.files.project) (char lparen)exists: ($result.files.project_exists)(char rparen)"
    }
}
