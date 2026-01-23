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
