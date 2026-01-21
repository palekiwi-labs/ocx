export def get-env-overrides [] {
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
    if ($env.OCX_OPENCODE_VERSION? | default null) != null {
        $overrides = ($overrides | append {key: "opencode_version", env_var: "OCX_OPENCODE_VERSION"})
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
    if ($env.OCX_USERNAME? | default null) != null {
        $overrides = ($overrides | append {key: "username", env_var: "OCX_USERNAME"})
    }
    if ($env.OCX_UID? | default null) != null {
        $overrides = ($overrides | append {key: "uid", env_var: "OCX_UID"})
    }
    if ($env.OCX_GID? | default null) != null {
        $overrides = ($overrides | append {key: "gid", env_var: "OCX_GID"})
    }
    if ($env.OCX_CUSTOM_BASE_DOCKERFILE? | default null) != null {
        $overrides = ($overrides | append {key: "custom_base_dockerfile", env_var: "OCX_CUSTOM_BASE_DOCKERFILE"})
    }
    if ($env.OCX_ENV_FILE? | default null) != null {
        $overrides = ($overrides | append {key: "env_file", env_var: "OCX_ENV_FILE"})
    }
    if ($env.OCX_READ_ONLY? | default null) != null {
        $overrides = ($overrides | append {key: "read_only", env_var: "OCX_READ_ONLY"})
    }
    if ($env.OCX_ADD_HOST_DOCKER_INTERNAL? | default null) != null {
        $overrides = ($overrides | append {key: "add_host_docker_internal", env_var: "OCX_ADD_HOST_DOCKER_INTERNAL"})
    }
    
    $overrides
}

export def apply-env-overrides [config: record] {
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
    
    # OCX_OPENCODE_VERSION
    let opencode_version_env = $env.OCX_OPENCODE_VERSION? | default null
    if $opencode_version_env != null {
        $result = ($result | upsert opencode_version $opencode_version_env)
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
    
    # OCX_USERNAME
    let username_env = $env.OCX_USERNAME? | default null
    if $username_env != null {
        $result = ($result | upsert username $username_env)
    }
    
    # OCX_UID
    let uid_env = $env.OCX_UID? | default null
    if $uid_env != null {
        $result = ($result | upsert uid ($uid_env | into int))
    }
    
    # OCX_GID
    let gid_env = $env.OCX_GID? | default null
    if $gid_env != null {
        $result = ($result | upsert gid ($gid_env | into int))
    }
    
    # OCX_CUSTOM_BASE_DOCKERFILE
    let custom_base_dockerfile_env = $env.OCX_CUSTOM_BASE_DOCKERFILE? | default null
    if $custom_base_dockerfile_env != null {
        $result = ($result | upsert custom_base_dockerfile $custom_base_dockerfile_env)
    }

    # OCX_ENV_FILE
    let env_file_env = $env.OCX_ENV_FILE? | default null
    if $env_file_env != null {
        $result = ($result | upsert env_file $env_file_env)
    }
    
    # OCX_READ_ONLY
    let read_only_env = $env.OCX_READ_ONLY? | default null
    if $read_only_env != null {
        $result = ($result | upsert read_only ($read_only_env | into bool))
    }
    
    # OCX_ADD_HOST_DOCKER_INTERNAL
    let add_host_docker_internal_env = $env.OCX_ADD_HOST_DOCKER_INTERNAL? | default null
    if $add_host_docker_internal_env != null {
        $result = ($result | upsert add_host_docker_internal ($add_host_docker_internal_env | into bool))
    }
    
    $result
}
