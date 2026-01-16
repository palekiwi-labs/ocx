# Hierarchical config management for OCX
# Priority: env vars > project config > global config > defaults

const DEFAULTS = {
    # Resource limits
    memory: "1024m"
    cpus: 1.0
    pids_limit: 100
    
    # Networking
    network: "bridge"
    publish_port: true
    port: null  # auto-generate if null
    
    # Container settings
    container_name: null  # auto-generate if null
    image_name: "localhost/ocx:latest"
    
    # Paths
    config_dir: "~/.config/opencode"
    rgignore_file: null  # optional
    
    # Security
    forbidden_paths: []  # array of relative paths to shadow-mount
    
    # Environment
    timezone: null  # use $env.TZ if null
    tmp_size: "500m"
    workspace_tmp_size: "500m"
}

# Load merged configuration from all sources
export def load [] {
    let result = get-with-sources
    $result.config
}

# Get configuration with source tracking (for debugging)
export def get-with-sources [] {
    # Start with defaults
    mut config = $DEFAULTS
    mut sources = {}
    
    # Track all keys from defaults
    for key in ($DEFAULTS | columns) {
        $sources = ($sources | insert $key "default")
    }
    
    # Merge global config if exists
    let global_config_path = ($DEFAULTS.config_dir | path expand | path join "ocx.json")
    mut global_exists = false
    if ($global_config_path | path exists) {
        let global = load-file $global_config_path
        $config = (merge $config $global)
        $global_exists = true
        
        # Track global overrides
        for key in ($global | columns) {
            if ($global | get $key) != null {
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
            if ($project | get $key) != null {
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

# Show merged configuration
export def show [] {
    let result = get-with-sources
    
    print "=== OCX Configuration ==="
    print ""
    print "Final merged configuration:"
    print ($result.config | to json --indent 2)
    print ""
    print "Config file locations:"
    print $"  Global:  ($result.files.global) (char lparen)exists: ($result.files.global_exists)(char rparen)"
    print $"  Project: ($result.files.project) (char lparen)exists: ($result.files.project_exists)(char rparen)"
}

# Show configuration with sources
export def show-sources [] {
    let result = get-with-sources
    
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

# Load config from JSON file
def load-file [path: string] {
    try {
        open $path | from json
    } catch {
        error make {
            msg: $"Failed to load config file: ($path)"
            help: "Ensure the file exists and contains valid JSON"
        }
    }
}

# Merge two configs (right overrides left)
# For simple values: override completely
# For arrays: replace, not concatenate
# For null values in override: keep base value
def merge [base: record, override: record] {
    mut result = $base
    
    for key in ($override | columns) {
        let override_value = $override | get $key
        
        # Only override if the value is not null
        if $override_value != null {
            $result = ($result | upsert $key $override_value)
        }
    }
    
    $result
}

# Get list of active environment variable overrides
def get-env-overrides [] {
    mut overrides = []
    
    if ($env.OCX_MEMORY? | default null) != null {
        $overrides = ($overrides | append {key: "memory", env_var: "OCX_MEMORY"})
    }
    if ($env.OCX_CPUS? | default null) != null {
        $overrides = ($overrides | append {key: "cpus", env_var: "OCX_CPUS"})
    }
    if ($env.OCX_PIDS_LIMIT? | default null) != null {
        $overrides = ($overrides | append {key: "pids_limit", env_var: "OCX_PIDS_LIMIT"})
    }
    if ($env.OCX_NETWORK? | default null) != null {
        $overrides = ($overrides | append {key: "network", env_var: "OCX_NETWORK"})
    }
    if ($env.OCX_PUBLISH_PORT? | default null) != null {
        $overrides = ($overrides | append {key: "publish_port", env_var: "OCX_PUBLISH_PORT"})
    }
    if ($env.OCX_PORT? | default null) != null {
        $overrides = ($overrides | append {key: "port", env_var: "OCX_PORT"})
    }
    if ($env.OCX_CONTAINER_NAME? | default null) != null {
        $overrides = ($overrides | append {key: "container_name", env_var: "OCX_CONTAINER_NAME"})
    }
    if ($env.OCX_IMAGE_NAME? | default null) != null {
        $overrides = ($overrides | append {key: "image_name", env_var: "OCX_IMAGE_NAME"})
    }
    if ($env.OCX_CONFIG_DIR? | default null) != null {
        $overrides = ($overrides | append {key: "config_dir", env_var: "OCX_CONFIG_DIR"})
    }
    if ($env.OCX_RGIGNORE_FILE? | default null) != null {
        $overrides = ($overrides | append {key: "rgignore_file", env_var: "OCX_RGIGNORE_FILE"})
    }
    if ($env.OCX_FORBIDDEN_PATHS? | default null) != null {
        $overrides = ($overrides | append {key: "forbidden_paths", env_var: "OCX_FORBIDDEN_PATHS"})
    }
    if ($env.TZ? | default null) != null {
        $overrides = ($overrides | append {key: "timezone", env_var: "TZ"})
    }
    if ($env.OCX_TMP_SIZE? | default null) != null {
        $overrides = ($overrides | append {key: "tmp_size", env_var: "OCX_TMP_SIZE"})
    }
    if ($env.OCX_WORKSPACE_TMP_SIZE? | default null) != null {
        $overrides = ($overrides | append {key: "workspace_tmp_size", env_var: "OCX_WORKSPACE_TMP_SIZE"})
    }
    
    $overrides
}

# Apply environment variable overrides
def apply-env-overrides [config: record] {
    mut result = $config
    
    # OCX_MEMORY
    let memory_env = $env.OCX_MEMORY? | default null
    if $memory_env != null {
        $result = ($result | upsert memory $memory_env)
    }
    
    # OCX_CPUS
    let cpus_env = $env.OCX_CPUS? | default null
    if $cpus_env != null {
        $result = ($result | upsert cpus ($cpus_env | into float))
    }
    
    # OCX_PIDS_LIMIT
    let pids_env = $env.OCX_PIDS_LIMIT? | default null
    if $pids_env != null {
        $result = ($result | upsert pids_limit ($pids_env | into int))
    }
    
    # OCX_NETWORK
    let network_env = $env.OCX_NETWORK? | default null
    if $network_env != null {
        $result = ($result | upsert network $network_env)
    }
    
    # OCX_PUBLISH_PORT
    let publish_port_env = $env.OCX_PUBLISH_PORT? | default null
    if $publish_port_env != null {
        $result = ($result | upsert publish_port ($publish_port_env | into bool))
    }
    
    # OCX_PORT
    let port_env = $env.OCX_PORT? | default null
    if $port_env != null {
        $result = ($result | upsert port ($port_env | into int))
    }
    
    # OCX_CONTAINER_NAME
    let container_name_env = $env.OCX_CONTAINER_NAME? | default null
    if $container_name_env != null {
        $result = ($result | upsert container_name $container_name_env)
    }
    
    # OCX_IMAGE_NAME
    let image_name_env = $env.OCX_IMAGE_NAME? | default null
    if $image_name_env != null {
        $result = ($result | upsert image_name $image_name_env)
    }
    
    # OCX_CONFIG_DIR
    let config_dir_env = $env.OCX_CONFIG_DIR? | default null
    if $config_dir_env != null {
        $result = ($result | upsert config_dir $config_dir_env)
    }
    
    # OCX_RGIGNORE_FILE
    let rgignore_env = $env.OCX_RGIGNORE_FILE? | default null
    if $rgignore_env != null {
        $result = ($result | upsert rgignore_file $rgignore_env)
    }
    
    # OCX_FORBIDDEN_PATHS (colon-separated)
    let forbidden_env = $env.OCX_FORBIDDEN_PATHS? | default null
    if $forbidden_env != null {
        let paths = ($forbidden_env | split row ":")
        $result = ($result | upsert forbidden_paths $paths)
    }
    
    # TZ (standard timezone env var)
    let tz_env = $env.TZ? | default null
    if $tz_env != null {
        $result = ($result | upsert timezone $tz_env)
    }
    
    # OCX_TMP_SIZE
    let tmp_size_env = $env.OCX_TMP_SIZE? | default null
    if $tmp_size_env != null {
        $result = ($result | upsert tmp_size $tmp_size_env)
    }
    
    # OCX_WORKSPACE_TMP_SIZE
    let workspace_tmp_size_env = $env.OCX_WORKSPACE_TMP_SIZE? | default null
    if $workspace_tmp_size_env != null {
        $result = ($result | upsert workspace_tmp_size $workspace_tmp_size_env)
    }
    
    $result
}

# Validate configuration values
def validate [config: record] {
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
    
    # Validate tmp sizes
    validate-memory ($config.tmp_size)
    validate-memory ($config.workspace_tmp_size)
}

# Validate memory format (e.g., "1024m", "2g", "512k")
def validate-memory [value: string] {
    if not ($value =~ '^\d+[kmg]$') {
        error make {
            msg: $"Invalid memory format: ($value)"
            help: "Memory must be in format: <number><unit> where unit is k, m, or g (e.g., '1024m', '2g')"
        }
    }
}
