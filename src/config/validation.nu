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
    
    # Validate overlay settings
    if $config.overlay_dockerfile != null {
        validate-overlay-dockerfile $config.overlay_dockerfile
    }
    
    if $config.overlay_image_name != null {
        validate-overlay-image-name $config.overlay_image_name
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

def validate-overlay-dockerfile [path: string] {
    if ($path | str length) == 0 {
        error make {
            msg: "overlay_dockerfile cannot be empty"
            help: "Provide a relative path to the Dockerfile"
        }
    }
    
    let project_path = ($path | path expand)
    let global_path = ("~/.config/ocx" | path join $path | path expand)
    
    if not (($project_path | path exists) or ($global_path | path exists)) {
        error make {
            msg: $"Overlay Dockerfile not found: ($path)"
            help: $"Checked:\n  - ($project_path)\n  - ($global_path)"
        }
    }
}

def validate-overlay-image-name [name: string] {
    if not ($name =~ '^[a-z0-9][a-z0-9_-]*$') {
        error make {
            msg: $"Invalid overlay_image_name: ($name)"
            help: "Must be lowercase, alphanumeric, with hyphens/underscores (cannot start with hyphen)"
        }
    }
}
