use defaults.nu DEFAULTS
use env.nu [get-env-overrides, apply-env-overrides]
use validation.nu validate

def load-file [path: string] {
    try {
        open $path
    } catch { |err|
        error make {
            msg: $"Failed to load config file: ($path)"
            label: {
                text: $"Parse error: ($err.msg)"
                span: (metadata $path).span
            }
            help: "Ensure the file contains valid JSON"
        }
    }
}

def merge [base: record, override: record] {
    mut result = $base
    
    for key in ($override | columns) {
        let override_value = $override | get $key
        
        # Only override if the value is not null
        if $override_value != null {
            # Check if this key exists in base and get its value
            let base_value = if $key in ($base | columns) {
                $base | get $key
            } else {
                null
            }
            
            # If both are lists, merge them (append + deduplicate)
            if (($override_value | describe) =~ "list") and (($base_value | describe) =~ "list") {
                let merged = ($base_value | append $override_value | uniq)
                $result = ($result | upsert $key $merged)
            } else {
                # For non-lists, replace as before
                $result = ($result | upsert $key $override_value)
            }
        }
    }
    
    $result
}

export def load [] {
    let result = get-with-sources
    $result.config
}

export def get-with-sources [] {
    # Start with defaults
    mut config = $DEFAULTS
    mut sources = {}
    
    # Track all keys from defaults
    for key in ($DEFAULTS | columns) {
        $sources = ($sources | insert $key "default")
    }
    
    # Merge global config if exists
    let global_config_path = ("~/.config/ocx/ocx.json" | path expand)
    mut global_exists = false
    if ($global_config_path | path exists) {
        let global = load-file $global_config_path
        $config = (merge $config $global)
        $global_exists = true
        
        # Track global overrides
        for key in ($global | columns) {
            let value = ($global | get $key)
            if $value != null {
                $sources = ($sources | upsert $key "global")
            }
        }
    }
    
    # Merge project config if exists
    let project_config_path = "./ocx.json"
    mut project_exists = false
    if ($project_config_path | path exists) {
        let project = load-file $project_config_path
        $config = (merge $config $project)
        $project_exists = true
        
        # Track project overrides
        for key in ($project | columns) {
            let value = ($project | get $key)
            if $value != null {
                $sources = ($sources | upsert $key "project")
            }
        }
    }
    
    # Track environment variable overrides
    let env_overrides = get-env-overrides
    for override in $env_overrides {
        $sources = ($sources | upsert $override.key "env")
    }
    
    # Apply environment variable overrides
    $config = (apply-env-overrides $config)
    
    # Validate the final config
    validate $config
    
    {
        config: $config
        sources: $sources
        files: {
            global: $global_config_path
            global_exists: $global_exists
            project: $project_config_path
            project_exists: $project_exists
        }
    }
}
