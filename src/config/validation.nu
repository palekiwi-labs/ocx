export def validate [config: record] {
    # Validate memory format
    validate-memory ($config.memory)
    
    # Validate CPUs
    if ($config.cpus <= 0) {
        error make {
            msg: $"Invalid cpus value: ($config.cpus)"
            help: "cpus must be greater than 0"
        }
    }
    
    # Validate pids_limit
    if ($config.pids_limit <= 0) {
        error make {
            msg: $"Invalid pids_limit value: ($config.pids_limit)"
            help: "pids_limit must be greater than 0"
        }
    }
    
    # Validate port if set
    if $config.port != null {
        if ($config.port < 1) or ($config.port > 65535) {
            error make {
                msg: $"Invalid port value: ($config.port)"
                help: "port must be between 1 and 65535"
            }
        }
    }
    
    # Validate forbidden_paths is array
    if ($config.forbidden_paths | describe) !~ "list" {
        error make {
            msg: "Invalid forbidden_paths value"
            help: "forbidden_paths must be an array of strings"
        }
    }
    
    # Validate opencode_version
    validate-opencode-version ($config.opencode_version)
    
    # Validate tmp sizes
    validate-memory ($config.tmp_size)
    validate-memory ($config.workspace_tmp_size)

    # Validate env_file
    if $config.env_file != null {
        if ($config.env_file | describe) !~ "string" {
             error make {
                msg: $"Invalid env_file value: ($config.env_file)"
                help: "env_file must be a string"
            }
        }
    }
    
    # Validate data_volumes_mode
    let valid_modes = ["always", "git", "never"]
    if $config.data_volumes_mode not-in $valid_modes {
        error make {
            msg: $"Invalid data_volumes_mode value: ($config.data_volumes_mode)"
            help: $"data_volumes_mode must be one of: ($valid_modes | str join ', ')"
        }
    }
    
    # Validate data_volumes_name if set
    if $config.data_volumes_name != null {
        if ($config.data_volumes_name | describe) !~ "string" {
            error make {
                msg: $"Invalid data_volumes_name value: ($config.data_volumes_name)"
                help: "data_volumes_name must be a string"
            }
        }
        
        # Validate Docker volume name format (lowercase alphanumeric + hyphens)
        if not ($config.data_volumes_name =~ '^[a-z0-9][a-z0-9-]*$') {
            error make {
                msg: $"Invalid data_volumes_name format: ($config.data_volumes_name)"
                help: "data_volumes_name must contain only lowercase letters, numbers, and hyphens, and start with a letter or number"
            }
        }
    }
    
    # Validate extra_data_volumes
    if ($config.extra_data_volumes | describe) !~ "record" {
        error make {
            msg: "Invalid extra_data_volumes value"
            help: "extra_data_volumes must be a record mapping keys to volume configurations"
        }
    }
    
    for key in ($config.extra_data_volumes | columns) {
        if not ($key =~ '^[a-z0-9][a-z0-9-]*$') {
            error make {
                msg: $"Invalid extra_data_volumes key format: ($key)"
                help: "Volume keys must contain only lowercase letters, numbers, and hyphens"
            }
        }
        
        let vol_config = ($config.extra_data_volumes | get $key)
        validate-volume-config $key $vol_config
    }
    
    # Validate version_cache_ttl_hours
    if $config.version_cache_ttl_hours <= 0 {
        error make {
            msg: $"Invalid version_cache_ttl_hours value: ($config.version_cache_ttl_hours)"
            help: "version_cache_ttl_hours must be greater than 0"
        }
    }

    # Validate opencode_command
    if $config.opencode_command != null {
        if ($config.opencode_command | describe) !~ "list" {
            error make {
                msg: "Invalid opencode_command value"
                help: "opencode_command must be an array of strings"
            }
        }
        
        if ($config.opencode_command | length) == 0 {
            error make {
                msg: "opencode_command cannot be empty"
                help: "opencode_command must contain at least one element"
            }
        }
        
        for item in $config.opencode_command {
            if ($item | describe) !~ "string" or ($item | str trim | str length) == 0 {
                error make {
                    msg: $"Invalid opencode_command element: ($item)"
                    help: "All opencode_command elements must be non-empty strings"
                }
            }
        }
    }
}

export def validate-volume-config [key: string, config: any] {
    # Must be a record
    if ($config | describe) !~ "record" {
        error make {
            msg: $"Invalid extra_data_volumes configuration for '($key)'"
            help: "Each value must be a record with 'target' field (required) and optional 'source', 'mode', 'type' fields"
        }
    }
    
    # Required: target field
    if ($config.target? == null) {
        error make {
            msg: $"Missing required 'target' field for extra_data_volumes key '($key)'"
            help: "Specify the container path where the volume/directory will be mounted"
        }
    }
    
    if ($config.target | describe) !~ "string" {
        error make {
            msg: $"Invalid 'target' field for extra_data_volumes key '($key)'"
            help: "Target must be a string path"
        }
    }
    
    # Optional: source field
    if ($config.source? != null) {
        if ($config.source | describe) !~ "string" {
            error make {
                msg: $"Invalid 'source' field for extra_data_volumes key '($key)'"
                help: "Source must be a string (volume name or host path)"
            }
        }
    }
    
    # Optional: mode field
    if ($config.mode? != null) {
        if $config.mode not-in ["rw", "ro"] {
            error make {
                msg: $"Invalid 'mode' field for extra_data_volumes key '($key)': ($config.mode)"
                help: "Mode must be 'rw' (read-write) or 'ro' (read-only)"
            }
        }
    }
    
    # Optional: type field
    if ($config.type? != null) {
        if $config.type not-in ["volume", "bind"] {
            error make {
                msg: $"Invalid 'type' field for extra_data_volumes key '($key)': ($config.type)"
                help: "Type must be 'volume' (Docker volume) or 'bind' (host bind mount)"
            }
        }
    }
    
    # Type-specific validations
    let vol_type = ($config.type? | default "volume")
    
    if $vol_type == "bind" {
        # Bind mounts require source
        if ($config.source? == null) {
            error make {
                msg: $"Missing required 'source' field for bind mount '($key)'"
                help: "Bind mounts require a source host path"
            }
        }
        
        # Bind mount source must be absolute path
        if not ($config.source | str starts-with "/") {
            error make {
                msg: $"Invalid 'source' path for bind mount '($key)': ($config.source)"
                help: "Bind mount source must be an absolute path starting with '/'"
            }
        }
    }
}

export def validate-memory [value: string] {
    if not ($value =~ '^\d+[kmg]$') {
        error make {
            msg: $"Invalid memory format: ($value)"
            help: "Memory must be in format: <number><unit> where unit is k, m, or g (e.g., '1024m', '2g')"
        }
    }
}

export def validate-opencode-version [value: string] {
    if $value == "latest" {
        return
    }
    
    let normalized = if ($value | str starts-with "v") {
        $value | str substring 1..
    } else {
        $value
    }
    
    let parts = ($normalized | split row ".")
    
    if ($parts | length) != 3 {
        error make {
            msg: $"Invalid opencode_version format: ($value)"
            help: "opencode_version must be 'latest' or semantic version (e.g., '1.2.3' or 'v1.2.3')"
        }
    }
    
    for part in $parts {
        if ($part | str length) == 0 {
            error make {
                msg: $"Invalid opencode_version format: ($value)"
                help: "opencode_version must be 'latest' or semantic version (e.g., '1.2.3' or 'v1.2.3')"
            }
        }
        
        if ($part | into int) == null {
            error make {
                msg: $"Invalid opencode_version format: ($value)"
                help: "opencode_version must be 'latest' or semantic version (e.g., '1.2.3' or 'v1.2.3')"
            }
        }
    }
}
